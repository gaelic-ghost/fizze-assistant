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
        self.warningStore = try WarningStore(path: configuration.databasePath)
        self.botUserID = try await restClient.getCurrentUser().id

        let guild = try await restClient.getGuild(id: configuration.guildID)
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
            logger.error("Failed to process event.", metadata: ["error": .string(String(describing: error))])
        }
    }

    private func handleMemberJoined(_ event: DiscordGuildMemberAddEvent) async throws {
        let configuration = await configurationStore.currentConfiguration()
        do {
            try await restClient.addRole(
                to: event.user.id,
                guildID: configuration.guildID,
                roleID: configuration.defaultMemberRoleID
            )
        } catch {
            let message = TemplateRenderer.render(configuration.roleAssignmentFailureMessage, user: event.user, guildName: guildName)
            if let modLogChannelID = configuration.modLogChannelID {
                try? await restClient.createMessage(channelID: modLogChannelID, content: message)
            } else {
                logger.warning("Mod log channel is not configured; skipping role assignment failure message.")
            }
            throw error
        }

        let welcome = TemplateRenderer.render(configuration.welcomeMessage, user: event.user, guildName: guildName)
        guard let welcomeChannelID = configuration.welcomeChannelID else {
            logger.warning("Welcome channel is not configured; skipping welcome message.")
            return
        }
        try await restClient.createMessage(channelID: welcomeChannelID, content: welcome)
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
            reason = try await classifier.classify(userID: event.user.id)
        } catch {
            logger.warning("Failed to classify member removal; using unknown fallback.", metadata: ["error": .string(String(describing: error))])
            reason = .unknown
        }

        let template: String
        switch reason {
        case .voluntary:
            template = configuration.voluntaryLeaveMessage
        case .kicked:
            template = configuration.kickMessage
        case .banned:
            template = configuration.banMessage
        case .unknown:
            template = configuration.unknownRemovalMessage
        }

        let announcement = TemplateRenderer.render(template, user: event.user, guildName: guildName)
        guard let leaveChannelID = configuration.leaveChannelID else {
            logger.warning("Leave channel is not configured; skipping leave announcement.")
            return
        }
        try await restClient.createMessage(channelID: leaveChannelID, content: announcement)
    }

    private func handleMessageCreate(_ event: DiscordMessageEvent) async throws {
        let configuration = await configurationStore.currentConfiguration()
        guard event.guildID == configuration.guildID else { return }
        guard event.webhookID == nil else { return }
        guard event.author.id != botUserID else { return }

        let engine = IconicResponseEngine(
            triggers: configuration.iconicTriggers,
            cooldownStore: cooldownStore,
            cooldown: configuration.triggerCooldownSeconds
        )
        if let response = await engine.response(for: event.content) {
            try await restClient.createMessage(channelID: event.channelID, content: response)
        }
    }
}
