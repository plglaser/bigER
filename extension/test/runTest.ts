import * as path from 'path';
import { runTests } from '@vscode/test-electron';

async function main() {
	try {
		// The folder containing the Extension Manifest package.json
		// Passed to `--extensionDevelopmentPath`
		const extensionDevelopmentPath = path.resolve(__dirname, '../../');

		// The path to the extension test script
		// Passed to --extensionTestsPath
		const extensionTestsPath = path.resolve(__dirname, './suite/index');

        // The workspace path
        const testWorkspacePath = path.resolve(__dirname, '../../../examples');

		// Download VS Code, unzip it and run the integration test
		await runTests({ 
            extensionDevelopmentPath, 
            extensionTestsPath,
            launchArgs: [
				testWorkspacePath,
				// This disables all extensions except the one being tested
				'--disable-extensions'
			]
        });
	} catch (err) {
		console.error('Failed to run tests');
		process.exit(1);
	}
}

main();