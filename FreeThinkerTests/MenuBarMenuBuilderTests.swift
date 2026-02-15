import XCTest
@testable import FreeThinker

final class MenuBarMenuBuilderRegressionTests: XCTestCase {
    func testFR007_MenuDescriptorsExcludeRemovedUpdatesCommand_SC01() {
        let descriptors = MenuBarMenuBuilder().makeDescriptors(
            state: MenuBarMenuState(
                isGenerating: false,
                launchAtLoginEnabled: false,
                selectedStylePreset: .socratic
            )
        )

        XCTAssertFalse(descriptors.contains { $0.title == "Check for Updates" })
        XCTAssertFalse(descriptors.contains { descriptor in
            guard let command = descriptor.command else { return false }
            switch command {
            case .openSettings, .openOnboardingGuide, .generate, .toggleLaunchAtLogin, .quit, .selectStylePreset:
                return false
            case .setStylePresetContrarian, .setStylePresetSocratic, .setStylePresetSystemsThinking:
                return true
            }
        })
    }

    func testFR008_MenuDescriptorsKeepSingleSelectedStylePreset_SC02() {
        let presets: [ProvocationStylePreset] = [.contrarian, .socratic, .systemsThinking]

        for preset in presets {
            let descriptors = MenuBarMenuBuilder().makeDescriptors(
                state: MenuBarMenuState(
                    isGenerating: false,
                    launchAtLoginEnabled: true,
                    selectedStylePreset: preset
                )
            )

            let styleDescriptors = descriptors.filter { descriptor in
                guard let command = descriptor.command else { return false }
                if case .selectStylePreset = command {
                    return true
                }
                return false
            }

            XCTAssertEqual(styleDescriptors.count, 3)
            XCTAssertEqual(styleDescriptors.filter { $0.isOn }.count, 1)

            let expectedCommand = MenuBarCommand.selectStylePreset(preset)

            XCTAssertTrue(styleDescriptors.contains { $0.command == expectedCommand && $0.isOn })
        }
    }
}
