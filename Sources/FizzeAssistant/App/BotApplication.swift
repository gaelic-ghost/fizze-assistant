import Foundation
import Logging

enum AppCommand {
    case run
    case registerCommands
    case check
}

enum BotApplication {
    // MARK: Entry Point

    static func run(command: AppCommand, options: SharedOptions) async throws {
        LoggingSystem.bootstrap(StreamLogHandler.standardError)

        var configuredLogger = Logger(label: "fizze-assistant")
        configuredLogger[metadataKey: "command"] = .string(String(describing: command))
        configuredLogger[metadataKey: "mode"] = .string(options.verbose ? "verbose" : "default")

        let configuration = try AppConfiguration.load(
            from: options.config.map(URL.init(fileURLWithPath:)),
            environment: ProcessInfo.processInfo.environment
        )

        let restClient = DiscordRESTClient(
            token: configuration.botToken,
            logger: configuredLogger
        )

        switch command {
        case .registerCommands:
            let registrar = CommandRegistrar(restClient: restClient, configuration: configuration, logger: configuredLogger)
            try await registrar.registerGuildCommands()
            configuredLogger.info("Registered guild commands.", metadata: ["guild_id": .string(configuration.guildID)])

        case .check:
            let report = try await PermissionReportBuilder(
                restClient: restClient,
                configuration: configuration,
                logger: configuredLogger
            ).build()
            print(report.renderText())
            if report.hasBlockingIssue {
                throw UserFacingError("Blocking setup issues were found. Fix them and rerun `fizze-assistant check`.")
            }

        case .run:
            let report = try await PermissionReportBuilder(
                restClient: restClient,
                configuration: configuration,
                logger: configuredLogger
            ).build()

            print(report.renderText())
            if report.hasBlockingIssue {
                throw UserFacingError("Blocking setup issues were found. Fix them and rerun `fizze-assistant check`.")
            }

            let bot = try await FizzeBot(
                configuration: configuration,
                restClient: restClient,
                logger: configuredLogger
            )

            try await bot.run()
        }
    }
}
