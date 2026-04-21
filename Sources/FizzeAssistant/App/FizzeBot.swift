import Foundation
import Logging

private enum EventHandlingError: LocalizedError {
    // MARK: Cases

    case memberJoinRoleAssignment(userID: DiscordSnowflake, roleID: DiscordSnowflake, guildID: DiscordSnowflake, underlying: Error)
    case memberJoinRoleAssignmentNotice(channelID: DiscordSnowflake, userID: DiscordSnowflake, underlying: Error)
    case memberJoinWelcomePost(channelID: DiscordSnowflake, userID: DiscordSnowflake, underlying: Error)
    case memberRemovalAnnouncement(channelID: DiscordSnowflake, userID: DiscordSnowflake, reason: LeaveReason, underlying: Error)
    case iconicMessageResponse(channelID: DiscordSnowflake, triggerText: String, underlying: Error)

    // MARK: LocalizedError

    var errorDescription: String? {
        switch self {
        case let .memberJoinRoleAssignment(userID, roleID, guildID, underlying):
            return "FizzeBot.handleMemberJoined: the bot could not assign role `\(roleID)` to user `\(userID)` in guild `\(guildID)`. The most likely cause is that the bot role is missing `Manage Roles` or is still below the target role in the Discord role list. Underlying error: \(Self.describe(underlying))"

        case let .memberJoinRoleAssignmentNotice(channelID, userID, underlying):
            return "FizzeBot.handleMemberJoined: role assignment failed for user `\(userID)`, and the follow-up staff notice also could not be posted to mod-log channel `\(channelID)`. The most likely cause is that the bot cannot send messages in that channel. Underlying error: \(Self.describe(underlying))"

        case let .memberJoinWelcomePost(channelID, userID, underlying):
            return "FizzeBot.handleMemberJoined: the bot could not post the welcome message for user `\(userID)` to channel `\(channelID)`. The most likely cause is that the bot does not have `Send Messages` in the configured welcome channel. Underlying error: \(Self.describe(underlying))"

        case let .memberRemovalAnnouncement(channelID, userID, reason, underlying):
            return "FizzeBot.handleMemberRemoved: the bot could not post the `\(reason)` departure announcement for user `\(userID)` to channel `\(channelID)`. The most likely cause is that the bot does not have `Send Messages` in the configured leave channel. Underlying error: \(Self.describe(underlying))"

        case let .iconicMessageResponse(channelID, triggerText, underlying):
            return "FizzeBot.handleMessageCreate: the bot matched iconic trigger text `\(triggerText)` but could not post the response in channel `\(channelID)`. The most likely cause is that the bot does not have `Send Messages` in that channel, or an embed in the iconic response was rejected by Discord. Underlying error: \(Self.describe(underlying))"
        }
    }

    // MARK: Private Helpers

    private static func describe(_ error: Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription {
            return localized
        }

        return String(describing: error)
    }
}

actor FizzeBot {
    // MARK: Stored Properties

    private static let mentionCooldownNotices = [
        "Whoa, whoa, slow down there. I'll give you time to catch your breath...",
        "*turns down the thermostat*\nCooldown mode initiated...",
        "*backs away slowly, startled by all the pings*",
    ]

    private let configurationStore: ConfigurationStore
    private let restClient: DiscordRESTClient
    private let logger: Logger
    private let warningStore: WarningStore
    private let interactionRouter: DiscordInteractionRouter
    private let responseCooldownGate = ResponseCooldownGate()
    private let banCache = ModerationEventCache()
    private let botUserID: String
    private let guildName: String
    private let messagePlanner: MessageResponsePlanner

    private var gatewayClient: DiscordGatewayClient?

    // MARK: Lifecycle

    init(configurationStore: ConfigurationStore, restClient: DiscordRESTClient, logger: Logger) async throws {
        self.configurationStore = configurationStore
        self.restClient = restClient
        self.logger = logger
        let configuration = await configurationStore.currentConfiguration()
        self.warningStore = try WarningStore(
            path: configuration.database_path,
            configuredGuildID: configuration.guild_id
        )
        self.interactionRouter = DiscordInteractionRouter(
            restClient: restClient,
            configurationStore: configurationStore,
            warningStore: self.warningStore,
            logger: logger
        )
        self.botUserID = try await restClient.getCurrentUser().id

        let guild = try await restClient.getGuild(id: configuration.guild_id)
        self.guildName = guild.name
        self.messagePlanner = MessageResponsePlanner(
            planResponse: { [configurationStore, responseCooldownGate, botUserID, guildName] event in
                await Self.planMessageResponse(
                    for: event,
                    configurationStore: configurationStore,
                    responseCooldownGate: responseCooldownGate,
                    botUserID: botUserID,
                    guildName: guildName
                )
            },
            executeResponse: { [restClient, logger] plan in
                await Self.executeMessageResponsePlan(
                    plan,
                    restClient: restClient,
                    logger: logger
                )
            }
        )
    }

    // MARK: Public API

    func run() async throws {
        let configuration = await configurationStore.currentConfiguration()
        let gatewayBot = try await restClient.getGatewayBot()
        guard let url = URL(string: "\(gatewayBot.url)?v=10&encoding=json") else {
            throw UserFacingError("FizzeBot.run: Discord returned a Gateway URL that this build could not parse, so the bot cannot open its event stream. The most likely cause is an unexpected Gateway URL format from Discord.")
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

    func handleEventForTesting(_ event: DiscordGatewayClient.Event) async {
        switch event {
        case let .message(message):
            await messagePlanner.enqueueAndWait(message)
        default:
            await handle(event)
        }
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
                await interactionRouter.handle(interaction, guildName: guildName)

            case let .message(message):
                await messagePlanner.enqueue(message)
            }
        } catch {
            logger.warning(
                "FizzeBot.handle: one Discord event did not finish cleanly, but the bot is still online and ready for the next event.",
                metadata: ["error": .string((error as? LocalizedError)?.errorDescription ?? String(describing: error))]
            )
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
                do {
                    try await restClient.createManagedMessage(
                        channel_id: mod_log_channel_id,
                        payload: DiscordMessageCreate(content: message, embeds: nil, components: nil, flags: nil),
                        kind: .modLogWarning,
                        logicalTargetID: event.user.id
                    )
                } catch {
                    let noticeError = EventHandlingError.memberJoinRoleAssignmentNotice(
                        channelID: mod_log_channel_id,
                        userID: event.user.id,
                        underlying: error
                    )
                    let noticeMessage = noticeError.errorDescription ?? "FizzeBot.handleMemberJoined: the role-assignment follow-up notice could not be posted to the mod log channel."
                    logger.warning("\(noticeMessage)")
                }
            } else {
                logger.warning("FizzeBot.handleMemberJoined: the bot could not post the role-assignment note because `mod_log_channel_id` is still empty in the active JSON config file. The most likely cause is that the mod log channel has not been configured yet.")
            }
            throw EventHandlingError.memberJoinRoleAssignment(
                userID: event.user.id,
                roleID: configuration.default_member_role_id,
                guildID: configuration.guild_id,
                underlying: error
            )
        }

        let welcome = TemplateRenderer.render(configuration.welcome_message, user: event.user, guildName: guildName)
        guard let welcome_channel_id = configuration.welcome_channel_id else {
            logger.warning("FizzeBot.handleMemberJoined: the welcome post is paused because `welcome_channel_id` is still empty in the active JSON config file. The most likely cause is that the welcome channel has not been configured yet.")
            return
        }
        do {
            try await restClient.createManagedMessage(
                channel_id: welcome_channel_id,
                payload: DiscordMessageCreate(content: welcome, embeds: nil, components: nil, flags: nil),
                kind: .welcomePost,
                logicalTargetID: event.user.id
            )
        } catch {
            throw EventHandlingError.memberJoinWelcomePost(
                channelID: welcome_channel_id,
                userID: event.user.id,
                underlying: error
            )
        }
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
            logger.warning("FizzeBot.handleMemberRemoved: the bot could not classify this departure, so it will fall back to the neutral leave message while staying online.", metadata: ["error": .string(String(describing: error))])
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
            logger.warning("FizzeBot.handleMemberRemoved: departure posts are paused because `leave_channel_id` is still empty in the active JSON config file. The most likely cause is that the leave channel has not been configured yet.")
            return
        }
        do {
            try await restClient.createManagedMessage(
                channel_id: leave_channel_id,
                payload: DiscordMessageCreate(content: announcement, embeds: nil, components: nil, flags: nil),
                kind: .leaveAnnouncement,
                logicalTargetID: event.user.id
            )
        } catch {
            throw EventHandlingError.memberRemovalAnnouncement(
                channelID: leave_channel_id,
                userID: event.user.id,
                reason: reason,
                underlying: error
            )
        }
    }

    // MARK: Messaging Helpers

    private static func planMessageResponse(
        for event: DiscordMessageEvent,
        configurationStore: ConfigurationStore,
        responseCooldownGate: ResponseCooldownGate,
        botUserID: String,
        guildName: String
    ) async -> PlannedMessageResponse? {
        let configuration = await configurationStore.currentConfiguration()
        guard event.guild_id == configuration.guild_id else { return nil }
        guard event.webhook_id == nil else { return nil }
        guard event.author.id != botUserID else { return nil }

        let engine = IconicResponseEngine(
            messagesByTrigger: configuration.iconic_messages,
            cooldownGate: responseCooldownGate,
            cooldown: configuration.trigger_cooldown_seconds,
            matchingMode: configuration.trigger_matching_mode
        )
        if let matched = engine.matchedResponse(for: event.content) {
            let iconicCooldownKey = "iconic:\(event.channel_id):\(matched.trigger)"
            if await responseCooldownGate.allowsResponse(
                for: iconicCooldownKey,
                cooldown: configuration.trigger_cooldown_seconds
            ) {
                return PlannedMessageResponse(
                    event: event,
                    action: .iconic(matched.response)
                )
            }
        }

        guard containsBotMention(in: event.content, botUserID: botUserID) else { return nil }
        let mentionCooldownKey = "mention:\(event.channel_id):\(event.author.id)"
        let mentionDecision = await responseCooldownGate.mentionBurstDecision(
            for: mentionCooldownKey,
            cooldown: configuration.trigger_cooldown_seconds
        )

        let response: String
        switch mentionDecision {
        case .sendStandardReply:
            guard let template = configuration.bot_mention_responses.randomElement() else {
                return nil
            }
            response = TemplateRenderer.render(template, user: event.author, guildName: guildName)

        case .sendCooldownNotice:
            response = Self.mentionCooldownNotices.randomElement() ?? "Cooldown mode initiated..."

        case .suppress:
            return nil
        }
        return PlannedMessageResponse(
            event: event,
            action: .mention(response)
        )
    }

    private static func executeMessageResponsePlan(
        _ plan: PlannedMessageResponse,
        restClient: DiscordRESTClient,
        logger: Logger
    ) async {
        do {
            switch plan.action {
            case let .iconic(response):
                try await sendIconicMessageResponse(response, for: plan.event, restClient: restClient)
            case let .mention(response):
                try await sendMentionResponse(response, for: plan.event, restClient: restClient)
            }
        } catch {
            logger.warning(
                "FizzeBot.executeMessageResponsePlan: one planned Discord message reply did not finish cleanly, but the message response lane is staying online for later events.",
                metadata: ["error": .string((error as? LocalizedError)?.errorDescription ?? String(describing: error))]
            )
        }
    }

    private static func sendIconicMessageResponse(
        _ response: IconicMessageConfiguration,
        for event: DiscordMessageEvent,
        restClient: DiscordRESTClient
    ) async throws {
        do {
            try await restClient.createManagedMessage(
                channel_id: event.channel_id,
                payload: response.discordMessageCreate,
                kind: .iconicReply,
                logicalTargetID: event.id
            )
        } catch {
            throw EventHandlingError.iconicMessageResponse(
                channelID: event.channel_id,
                triggerText: event.content,
                underlying: error
            )
        }
    }

    private static func sendMentionResponse(
        _ response: String,
        for event: DiscordMessageEvent,
        restClient: DiscordRESTClient
    ) async throws {
        do {
            try await restClient.createManagedMessage(
                channel_id: event.channel_id,
                payload: DiscordMessageCreate(content: response, embeds: nil, components: nil, flags: nil),
                kind: .mentionReply,
                logicalTargetID: event.id
            )
        } catch {
            throw EventHandlingError.iconicMessageResponse(
                channelID: event.channel_id,
                triggerText: event.content,
                underlying: error
            )
        }
    }

    private static func containsBotMention(in content: String, botUserID: String) -> Bool {
        content.contains("<@\(botUserID)>") || content.contains("<@!\(botUserID)>")
    }
}

private struct PlannedMessageResponse: Sendable {
    enum Action: Sendable {
        case iconic(IconicMessageConfiguration)
        case mention(String)
    }

    let event: DiscordMessageEvent
    let action: Action
}

private actor MessageResponsePlanner {
    private struct QueuedMessage {
        let event: DiscordMessageEvent
        let completion: CheckedContinuation<Void, Never>?
    }

    private let planResponse: @Sendable (DiscordMessageEvent) async -> PlannedMessageResponse?
    private let executeResponse: @Sendable (PlannedMessageResponse) async -> Void

    private var queuedMessages: [QueuedMessage] = []
    private var isPlanningMessage = false

    init(
        planResponse: @escaping @Sendable (DiscordMessageEvent) async -> PlannedMessageResponse?,
        executeResponse: @escaping @Sendable (PlannedMessageResponse) async -> Void
    ) {
        self.planResponse = planResponse
        self.executeResponse = executeResponse
    }

    func enqueue(_ event: DiscordMessageEvent) {
        queuedMessages.append(QueuedMessage(event: event, completion: nil))
        scheduleIfNeeded()
    }

    func enqueueAndWait(_ event: DiscordMessageEvent) async {
        await withCheckedContinuation { continuation in
            queuedMessages.append(QueuedMessage(event: event, completion: continuation))
            scheduleIfNeeded()
        }
    }

    private func scheduleIfNeeded() {
        guard !isPlanningMessage, !queuedMessages.isEmpty else { return }
        let queuedMessage = queuedMessages.removeFirst()
        isPlanningMessage = true

        Task { [planResponse, executeResponse] in
            let plannedResponse = await planResponse(queuedMessage.event)

            if let completion = queuedMessage.completion {
                if let plannedResponse {
                    await executeResponse(plannedResponse)
                }
                completion.resume()
                await self.finishPlanning()
                return
            }

            await self.finishPlanning()

            guard let plannedResponse else { return }
            Task {
                await executeResponse(plannedResponse)
            }
        }
    }

    private func finishPlanning() async {
        isPlanningMessage = false
        scheduleIfNeeded()
    }
}
