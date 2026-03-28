import Foundation
import Logging

enum AppCommand {
    case run
    case registerCommands
    case check
    case configShow
    case configInit
    case configValidate
}

enum BotApplication {
    // MARK: Entry Point

    static func run(command: AppCommand, options: SharedOptions) async throws {
        LoggingSystem.bootstrap(StreamLogHandler.standardError)

        var configuredLogger = Logger(label: "fizze-assistant")
        configuredLogger[metadataKey: "command"] = .string(String(describing: command))
        configuredLogger[metadataKey: "mode"] = .string(options.verbose ? "verbose" : "default")

        let configurationStore = try ConfigurationStore.load(
            from: options.config.map(URL.init(fileURLWithPath:)),
            environment: ProcessInfo.processInfo.environment
        )
        switch command {
        case .configShow:
            let configurationFile = await configurationStore.configurationFileContents()
            print(try configurationFile.prettyPrintedJSON())

        case .configInit:
            let url = try await configurationStore.initializeConfigurationFileIfNeeded()
            print("Configuration is available at \(url.path)")

        case .configValidate:
            let configurationFile = await configurationStore.configurationFileContents()
            print("Configuration path: \(options.config ?? "fizze-assistant.json")")
            if configurationFile.warnings.isEmpty {
                print("Configuration is ready for runtime use.")
            } else {
                print("Configuration warnings:")
                for warning in configurationFile.warnings {
                    print("- \(warning)")
                }
            }

        case .registerCommands, .check, .run:
            let configuration = try await configurationStore.readyConfiguration()
            let restClient = DiscordRESTClient(
                token: configuration.botToken,
                logger: configuredLogger
            )

            switch command {
        case .registerCommands:
            let registrar = CommandRegistrar(restClient: restClient, configuration: configuration, logger: configuredLogger)
            try await registrar.registerGuildCommands()
            configuredLogger.info("Registered guild commands.", metadata: ["guild_id": .string(configuration.guild_id)])

        case .check:
            let report = try await PermissionReportBuilder(
                restClient: restClient,
                configuration: configuration,
                logger: configuredLogger
            ).build()
            print(report.renderText())

        case .run:
            let report = try await PermissionReportBuilder(
                restClient: restClient,
                configuration: configuration,
                logger: configuredLogger
            ).build()

            print(report.renderText())
            print("Startup is continuing with the guidance above.")

            let bot = try await FizzeBot(
                configurationStore: configurationStore,
                restClient: restClient,
                logger: configuredLogger
            )

            try await bot.run()
            default:
                break
            }
        }
    }
}
