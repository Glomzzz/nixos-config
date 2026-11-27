/**
 * Emacs-style buffer jumps for the main prompt editor:
 *   alt+<  move to the start of the input
 *   alt+>  move to the end of the input
 *
 * pi has no built-in editor action for buffer start/end, so this extension
 * swaps in a CustomEditor subclass that handles those two keys and delegates
 * everything else to the default behaviour.
 */
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey } from "@earendil-works/pi-tui";

const UP = "\x1b[A";
const DOWN = "\x1b[B";
const HOME = "\x1b[H";
const END = "\x1b[F";

class BufferJumpEditor extends CustomEditor {
	handleInput(data: string): void {
		if (matchesKey(data, "alt+<")) {
			this.moveToBufferStart();
			return;
		}
		if (matchesKey(data, "alt+>")) {
			this.moveToBufferEnd();
			return;
		}
		super.handleInput(data);
	}

	private moveToBufferStart(): void {
		// Wrapped lines take several up-presses per logical line, so bound the loop.
		let budget = this.getText().length + this.getLines().length;
		while (this.getCursor().line > 0 && budget-- > 0) {
			super.handleInput(UP);
		}
		super.handleInput(HOME);
	}

	private moveToBufferEnd(): void {
		const lastLine = this.getLines().length - 1;
		let budget = this.getText().length + this.getLines().length;
		while (this.getCursor().line < lastLine && budget-- > 0) {
			super.handleInput(DOWN);
		}
		super.handleInput(END);
	}
}

interface EditorSettings {
	editorPaddingX: number;
	autocompleteMaxVisible: number;
}

// Mirror the user's editor layout settings so the replacement looks the same.
function readEditorSettings(): EditorSettings {
	const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
	const defaults: EditorSettings = { editorPaddingX: 0, autocompleteMaxVisible: 5 };
	try {
		const raw = JSON.parse(readFileSync(join(agentDir, "settings.json"), "utf-8"));
		return {
			editorPaddingX: typeof raw.editorPaddingX === "number" ? raw.editorPaddingX : defaults.editorPaddingX,
			autocompleteMaxVisible:
				typeof raw.autocompleteMaxVisible === "number" ? raw.autocompleteMaxVisible : defaults.autocompleteMaxVisible,
		};
	} catch {
		return defaults;
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		const settings = readEditorSettings();
		ctx.ui.setEditorComponent(
			(tui, theme, keybindings) =>
				new BufferJumpEditor(tui, theme, keybindings, {
					paddingX: settings.editorPaddingX,
					autocompleteMaxVisible: settings.autocompleteMaxVisible,
					embedWorkingStatus: true,
				}),
		);
	});
}
