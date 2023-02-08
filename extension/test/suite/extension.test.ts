import * as assert from 'assert';
import * as vscode from 'vscode';
suite('Extension Tests', () => {
	
    test('Extension should be present', () => {
        assert.ok(vscode.extensions.getExtension('BIGModelingTools.erdiagram'));
    });

    test('should activate', function () {
        this.timeout(1 * 60 * 1000);
        return vscode.extensions.getExtension('BIGModelingTools.erdiagram')?.activate()
            .then((api) => {
                assert.ok(true);
            });
    });

    test('should register new model commands', function () {
        this.timeout(1 * 60 * 1000);
        return vscode.commands.getCommands(true).then((commands) => {
            const COMMANDS = [
                'erdiagram.model.newEmpty',
                'erdiagram.model.newSample',
            ];
            const foundCommands = commands.filter((value) => {
                return COMMANDS.indexOf(value) >= 0 || value.startsWith('erdiagram.model.');
            });
            assert.strictEqual(foundCommands.length, COMMANDS.length);
        });
    });
});