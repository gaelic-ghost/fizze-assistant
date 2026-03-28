import Foundation
import Logging

actor FizzeBot {
    // MARK: Stored Properties

    private let configurationStore: ConfigurationStore
    private let restClient: DiscordRESTClient
    private let logger: Logger
    private let warningStore: WarningStore
    private let cooldownStore = TriggerCooldownStore()
    private let banCache = ModerationEventCache()
    private let botUserID: String

    private var guildName = ""
    private var gatewayClient: DiscordGatewayClient?

    // MARK: Lifecycle

    init(configurationStore: ConfigurationStore, restClient: DiscordRESTClient, logger: Logger) async throws {
        self.configurationStore = configurationStore
        self.restClient = restClient
        self.logger = logger
        let configuration = await configurationStore.currentConfiguration()
        self.warningStore = try WarningStore(path: configuration.database_path)
        self.botUserID = try await restClient.getCurrentUser().id

        let guild = try await restClient.getGuild(id: configuration.guild_id)
        self.guildName = guild.name
    }

    // MARK: Run Loop

    func run() async throws {
        let configuration = await configurationStore.currentConfiguration()
        let gatewayBot = try await restClient.getGatewayBot()
        guard let url = URL(string: "\(gatewayBot.url)?v=10&encoding=json") else {
            throw UserFacingError("Discord returned an invalid Gateway URL.")
        }

        let intents = (1 << 0) | (1 << 1) | (1 << 9) | (1 << 15)
        let gateway = DiscordGatewayClient(
            token: configuration.botToken,
            gatewayURL: url,
            intents: intents,
            logger: logger
        ) { [weak self] event in
            await self?.handle(event)
        }
        self.gatewayClient = gateway
        try await gateway.start()

        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(60))
        }
    }

    func stop() async {
        await gatewayClient?.stop()
    }

    // MARK: Event Handling

    private func handle(_ event: DiscordGatewayClient.Event) async {
        do {
            switch event {
            case let .memberJoined(join):
                try await handleMemberJoined(join)

            case let .memberRemoved(remove):
                try await handleMemberRemoved(remove)

            case let .memberBanned(ban):
                await banCache.recordBan(for: ban.user.id)

            case let .interaction(interaction):
                let handler = InteractionHandler(
                    restClient: restClient,
                    configurationStore: configurationStore,
                    warningStore: warningStore,
                    logger: logger
                )
                await handler.handle(interaction, guildName: guildName)

            case let .message(message):
                try await handleMessageCreate(message)
            }
        } catch {
            logger.warning("One event did not complete cleanly, but the bot is still running.", metadata: ["error": .string(String(describing: error))])
        }
    }

    private func handleMemberJoined(_ event: DiscordGuildMemberAddEvent) async throws {
        let configuration = await configurationStore.currentConfiguration()
        do {
            try await restClient.addRole(
                to: event.user.id,
                guild_id: configuration.guild_id,
                role_id: configuration.default_member_role_id
            )
        } catch {
            let message = TemplateRenderer.render(configuration.role_assignment_failure_message, user: event.user, guildName: guildName)
            if let mod_log_channel_id = configuration.mod_log_channel_id {
                try? await restClient.createMessage(channel_id: mod_log_channel_id, content: message)
            } else {
                logger.warning("Mod log channel is not configured yet, so the role-assignment note will stay local for now.")
            }
            throw error
        }

        let welcome = TemplateRenderer.render(configuration.welcome_message, user: event.user, guildName: guildName)
        guard let welcome_channel_id = configuration.welcome_channel_id else {
            logger.warning("Welcome channel is not configured yet, so the welcome post will stay off for now.")
            return
        }
        try await restClient.createMessage(channel_id: welcome_channel_id, content: welcome)
    }

    private func handleMemberRemoved(_ event: DiscordGuildMemberRemoveEvent) async throws {
        let configuration = await configurationStore.currentConfiguration()
        let classifier = LeaveReasonClassifier(
            restClient: restClient,
            configuration: configuration,
            banCache: banCache
        )
        let reason: LeaveReason
        do {
            reason = try await classifier.classify(user_id: event.user.id)
        } catch {
            logger.warning("Departure classification was not available for this member, so the neutral leave message will be used.", metadata: ["error": .string(String(describing: error))])
            reason = .unknown
        }

        let template: String
        switch reason {
        case .voluntary:
            template = configuration.voluntary_leave_message
        case .kicked:
            template = configuration.kick_message
        case .banned:
            template = configuration.ban_message
        case .unknown:
            template = configuration.unknown_removal_message
        }

        let announcement = TemplateRenderer.render(template, user: event.user, guildName: guildName)
        guard let leave_channel_id = configuration.leave_channel_id else {
            logger.warning("Leave channel is not configured yet, so departure posts will stay off for now.")
            return
        }
        try await restClient.createMessage(channel_id: leave_channel_id, content: announcement)
    }

    private func handleMessageCreate(_ event: DiscordMessageEvent) async throws {
        let configuration = await configurationStore.currentConfiguration()
        guard event.guild_id == configuration.guild_id else { return }
        guard event.webhook_id == nil else { return }
        guard event.author.id != botUserID else { return }

        let engine = IconicResponseEngine(
            triggers: configuration.iconic_triggers,
            cooldownStore: cooldownStore,
            cooldown: configuration.trigger_cooldown_seconds
        )
        if let response = await engine.response(for: event.content) {
            try await restClient.createMessage(channel_id: event.channel_id, content: response)
        }
    }
}
