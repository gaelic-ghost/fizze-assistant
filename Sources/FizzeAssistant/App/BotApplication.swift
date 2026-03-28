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
            let runtime = await configurationStore.runtimeConfiguration()
            print(try runtime.prettyPrintedJSON())

        case .configInit:
            let url = try await configurationStore.initializeRuntimeConfigurationFileIfNeeded()
            print("Runtime configuration is available at \(url.path)")

        case .configValidate:
            let runtime = await configurationStore.runtimeConfiguration()
            let install = await configurationStore.installConfiguration()
            print("Runtime configuration path: \(install.runtimeConfigPath)")
            if install.setupWarnings.isEmpty {
                print("Install configuration is ready for runtime use.")
            } else {
                print("Install configuration warnings:")
                for warning in install.setupWarnings {
                    print("- \(warning)")
                }
            }
            if runtime.warnings.isEmpty {
                print("Runtime configuration is valid.")
            } else {
                print("Runtime configuration warnings:")
                for warning in runtime.warnings {
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
