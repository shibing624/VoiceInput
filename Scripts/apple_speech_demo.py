#!/usr/bin/env python3
import argparse
import queue
import sys
import tkinter as tk
from datetime import datetime
from tkinter import messagebox
from tkinter import ttk

try:
    from AVFoundation import AVAudioEngine, AVCaptureDevice, AVMediaTypeAudio
    from Foundation import NSBundle, NSLocale
    from Speech import (
        SFSpeechAudioBufferRecognitionRequest,
        SFSpeechRecognizer,
        SFSpeechRecognizerAuthorizationStatusAuthorized,
        SFSpeechRecognizerAuthorizationStatusDenied,
        SFSpeechRecognizerAuthorizationStatusNotDetermined,
        SFSpeechRecognizerAuthorizationStatusRestricted,
    )
except ModuleNotFoundError as error:
    print("Missing PyObjC Speech dependencies.", file=sys.stderr)
    print(
        "Install with: "
        "/Users/xuming/miniconda3/envs/py3.12/bin/python3 -m pip install "
        "pyobjc-core pyobjc-framework-Cocoa pyobjc-framework-AVFoundation pyobjc-framework-Speech",
        file=sys.stderr,
    )
    raise


LANGUAGES = [
    ("English", "en-US"),
    ("Simplified Chinese", "zh-CN"),
    ("Traditional Chinese", "zh-TW"),
    ("Japanese", "ja-JP"),
    ("Korean", "ko-KR"),
]
FORCE_FINALIZE_DELAY_MS = 1500
REQUIRED_BUNDLE_KEYS = [
    "NSSpeechRecognitionUsageDescription",
    "NSMicrophoneUsageDescription",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Local Apple Speech realtime ASR demo")
    parser.add_argument("--check", action="store_true", help="Print Python and current permission states, then exit")
    return parser.parse_args()


def speech_auth_label(status: int) -> str:
    mapping = {
        SFSpeechRecognizerAuthorizationStatusNotDetermined: "not_determined",
        SFSpeechRecognizerAuthorizationStatusDenied: "denied",
        SFSpeechRecognizerAuthorizationStatusRestricted: "restricted",
        SFSpeechRecognizerAuthorizationStatusAuthorized: "authorized",
    }
    return mapping.get(status, f"unknown({status})")


def microphone_auth_label(status: int) -> str:
    mapping = {
        0: "not_determined",
        1: "restricted",
        2: "denied",
        3: "authorized",
    }
    return mapping.get(int(status), f"unknown({status})")


def missing_bundle_usage_description_keys() -> list[str]:
    info = NSBundle.mainBundle().infoDictionary()
    if info is None:
        return list(REQUIRED_BUNDLE_KEYS)

    missing_keys: list[str] = []
    for key in REQUIRED_BUNDLE_KEYS:
        value = info.get(key)
        if not value:
            missing_keys.append(key)
    return missing_keys


def bundle_runtime_error_message(missing_keys: list[str]) -> str:
    keys = ", ".join(missing_keys)
    return (
        "macOS blocks Speech/Microphone access for a plain Python process without "
        f"bundle privacy keys: {keys}.\n\n"
        "Do not run this demo with bare `python apple_speech_demo.py`.\n"
        "Build and launch the app bundle instead:\n"
        "  bash Scripts/build_apple_speech_demo_app.sh\n"
        "  open \"Scripts/dist/Apple Speech Demo.app\""
    )


class AppleSpeechDemo:
    def __init__(self) -> None:
        self.ui_queue: queue.Queue[tuple[str, object]] = queue.Queue()
        self.is_recording = False
        self.awaiting_final_result = False
        self.session_count = 0
        self.committed_lines: list[str] = []
        self.current_partial_line = ""
        self.pending_finalize_after_id: str | None = None

        self.audio_engine = None
        self.input_node = None
        self.recognizer = None
        self.recognition_request = None
        self.recognition_task = None
        self.recognition_handler = None
        self.audio_tap_block = None
        self.speech_authorization_status = SFSpeechRecognizerAuthorizationStatusNotDetermined
        self.microphone_authorization_status = 0

        self.root = tk.Tk()
        self.root.title("Apple Speech ASR Demo")
        self.root.geometry("960x760")
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

        self.status_var = tk.StringVar(value="Initializing...")
        self.python_var = tk.StringVar(value=f"Python: {sys.executable}")
        self.engine_var = tk.StringVar(value="Engine: Apple Speech (macOS native)")
        self.language_var = tk.StringVar(value=LANGUAGES[1][1])
        self.speech_permission_var = tk.StringVar(value="Speech permission: checking...")
        self.microphone_permission_var = tk.StringVar(value="Microphone permission: checking...")
        self.record_button_var = tk.StringVar(value="Start Recording")

        self.build_ui()
        self.root.after(100, self.poll_ui_queue)
        self.initialize_permissions()

    def build_ui(self) -> None:
        container = tk.Frame(self.root, padx=16, pady=16)
        container.pack(fill=tk.BOTH, expand=True)

        header = tk.Label(
            container,
            text="Apple Speech Realtime ASR Demo",
            font=("Helvetica", 22, "bold"),
            anchor="w",
        )
        header.pack(fill=tk.X, pady=(0, 12))

        for variable in [
            self.status_var,
            self.python_var,
            self.engine_var,
            self.speech_permission_var,
            self.microphone_permission_var,
        ]:
            label = tk.Label(container, textvariable=variable, anchor="w", justify=tk.LEFT, wraplength=920)
            label.pack(fill=tk.X, pady=2)

        controls = tk.Frame(container)
        controls.pack(fill=tk.X, pady=(16, 12))

        language_label = tk.Label(controls, text="Language:")
        language_label.pack(side=tk.LEFT)

        self.language_combo = ttk.Combobox(
            controls,
            state="readonly",
            values=[title for title, _ in LANGUAGES],
            width=24,
        )
        self.language_combo.current(1)
        self.language_combo.bind("<<ComboboxSelected>>", self.on_language_selected)
        self.language_combo.pack(side=tk.LEFT, padx=(8, 12))

        self.record_button = tk.Button(
            controls,
            textvariable=self.record_button_var,
            command=self.toggle_recording,
            width=18,
            state=tk.DISABLED,
        )
        self.record_button.pack(side=tk.LEFT)

        self.clear_button = tk.Button(
            controls,
            text="Clear Transcript",
            command=self.clear_transcript,
            width=18,
        )
        self.clear_button.pack(side=tk.LEFT, padx=(12, 0))

        transcript_label = tk.Label(container, text="Transcript History", anchor="w", font=("Helvetica", 14, "bold"))
        transcript_label.pack(fill=tk.X, pady=(8, 6))

        self.transcript_text = tk.Text(container, wrap=tk.WORD, font=("Menlo", 14))
        self.transcript_text.pack(fill=tk.BOTH, expand=True)
        self.transcript_text.insert(
            tk.END,
            "This demo uses macOS native Apple Speech via PyObjC.\n"
            "Grant microphone and speech recognition permissions when prompted.\n",
        )
        self.transcript_text.configure(state=tk.DISABLED)

    def initialize_permissions(self) -> None:
        self.speech_authorization_status = int(SFSpeechRecognizer.authorizationStatus())
        self.microphone_authorization_status = int(AVCaptureDevice.authorizationStatusForMediaType_(AVMediaTypeAudio))
        self.update_permission_labels()

        if self.speech_authorization_status == SFSpeechRecognizerAuthorizationStatusNotDetermined:
            SFSpeechRecognizer.requestAuthorization_(self.on_speech_authorized)

        if self.microphone_authorization_status == 0:
            AVCaptureDevice.requestAccessForMediaType_completionHandler_(AVMediaTypeAudio, self.on_microphone_authorized)

        self.refresh_controls()

    def on_speech_authorized(self, status: int) -> None:
        self.ui_queue.put(("speech_auth", int(status)))

    def on_microphone_authorized(self, granted: bool) -> None:
        self.ui_queue.put(("microphone_auth", bool(granted)))

    def update_permission_labels(self) -> None:
        self.speech_permission_var.set(
            f"Speech permission: {speech_auth_label(int(self.speech_authorization_status))}"
        )
        self.microphone_permission_var.set(
            f"Microphone permission: {microphone_auth_label(int(self.microphone_authorization_status))}"
        )

    def refresh_controls(self) -> None:
        speech_ok = self.speech_authorization_status == SFSpeechRecognizerAuthorizationStatusAuthorized
        microphone_ok = self.microphone_authorization_status == 3
        self.record_button.configure(state=tk.NORMAL if speech_ok and microphone_ok else tk.DISABLED)
        self.language_combo.configure(state="disabled" if self.is_recording else "readonly")

    def on_language_selected(self, event: object | None = None) -> None:
        selection = self.language_combo.current()
        if selection < 0:
            return
        self.language_var.set(LANGUAGES[selection][1])
        self.status_var.set(f"Status: language set to {LANGUAGES[selection][0]}")

    def current_language_title(self) -> str:
        selection = self.language_combo.current()
        if selection < 0:
            return "Unknown"
        return LANGUAGES[selection][0]

    def current_locale_identifier(self) -> str:
        selection = self.language_combo.current()
        if selection < 0:
            return "zh-CN"
        return LANGUAGES[selection][1]

    def toggle_recording(self) -> None:
        if self.is_recording:
            self.stop_recording()
        else:
            self.start_recording()

    def start_recording(self) -> None:
        if self.speech_authorization_status != SFSpeechRecognizerAuthorizationStatusAuthorized:
            messagebox.showwarning("Speech Permission Missing", "Speech recognition permission is not granted.")
            return
        if self.microphone_authorization_status != 3:
            messagebox.showwarning("Microphone Permission Missing", "Microphone permission is not granted.")
            return

        locale_identifier = self.current_locale_identifier()
        recognizer = SFSpeechRecognizer.alloc().initWithLocale_(NSLocale.localeWithLocaleIdentifier_(locale_identifier))
        if recognizer is None:
            messagebox.showerror("Recognizer Error", f"Apple Speech is unavailable for locale {locale_identifier}.")
            return

        self.session_count += 1
        self.append_session_header()
        self.current_partial_line = ""
        self.render_transcript()

        self.recognition_request = SFSpeechAudioBufferRecognitionRequest.alloc().init()
        self.recognition_request.setShouldReportPartialResults_(True)
        self.audio_engine = AVAudioEngine.alloc().init()
        self.input_node = self.audio_engine.inputNode()
        self.recognizer = recognizer

        recording_format = self.input_node.outputFormatForBus_(0)

        def tap_block(buffer, when) -> None:
            if self.recognition_request is not None:
                self.recognition_request.appendAudioPCMBuffer_(buffer)

        self.audio_tap_block = tap_block
        self.input_node.installTapOnBus_bufferSize_format_block_(0, 1024, recording_format, self.audio_tap_block)

        def recognition_handler(result, error) -> None:
            if result is not None:
                text = result.bestTranscription().formattedString()
                self.ui_queue.put(("draft", text))
                if result.isFinal():
                    self.ui_queue.put(("final", text))
            if error is not None:
                self.ui_queue.put(("error", str(error)))

        self.recognition_handler = recognition_handler
        self.recognition_task = self.recognizer.recognitionTaskWithRequest_resultHandler_(
            self.recognition_request,
            self.recognition_handler,
        )

        self.audio_engine.prepare()
        start_result = self.audio_engine.startAndReturnError_(None)
        if isinstance(start_result, tuple):
            started, error = start_result
        else:
            started, error = bool(start_result), None

        if not started:
            self.cleanup_recognition(cancel_task=True)
            messagebox.showerror("Audio Engine Error", str(error or "Failed to start AVAudioEngine"))
            return

        self.is_recording = True
        self.awaiting_final_result = False
        self.record_button_var.set("Stop Recording")
        self.status_var.set(f"Status: recording with Apple Speech ({self.current_language_title()})")
        self.refresh_controls()

    def stop_recording(self) -> None:
        if not self.is_recording:
            return

        self.is_recording = False
        self.awaiting_final_result = True
        self.record_button_var.set("Start Recording")
        self.status_var.set("Status: finalizing...")

        self.stop_audio_engine()
        if self.recognition_request is not None:
            self.recognition_request.endAudio()

        self.refresh_controls()
        self.schedule_force_finalize()

    def stop_audio_engine(self) -> None:
        if self.input_node is not None:
            try:
                self.input_node.removeTapOnBus_(0)
            except Exception:
                pass

        if self.audio_engine is not None:
            try:
                self.audio_engine.stop()
            except Exception:
                pass

    def schedule_force_finalize(self) -> None:
        self.cancel_pending_force_finalize()
        self.pending_finalize_after_id = self.root.after(FORCE_FINALIZE_DELAY_MS, self.force_finalize_after_stop)

    def cancel_pending_force_finalize(self) -> None:
        if self.pending_finalize_after_id is not None:
            self.root.after_cancel(self.pending_finalize_after_id)
            self.pending_finalize_after_id = None

    def force_finalize_after_stop(self) -> None:
        self.pending_finalize_after_id = None
        if not self.awaiting_final_result:
            return
        fallback_text = self.current_partial_line.strip()
        if fallback_text:
            self.commit_final_text(fallback_text)
        else:
            self.cleanup_recognition(cancel_task=True)
            self.status_var.set("Status: idle")

    def commit_final_text(self, text: str) -> None:
        cleaned = text.strip()
        self.awaiting_final_result = False
        self.cancel_pending_force_finalize()

        if cleaned and (not self.committed_lines or self.committed_lines[-1] != cleaned):
            self.committed_lines.append(cleaned)
        self.current_partial_line = ""
        self.render_transcript()
        self.cleanup_recognition(cancel_task=False)
        self.status_var.set("Status: idle")

    def cleanup_recognition(self, cancel_task: bool) -> None:
        self.stop_audio_engine()

        if cancel_task and self.recognition_task is not None:
            try:
                self.recognition_task.cancel()
            except Exception:
                pass

        self.audio_engine = None
        self.input_node = None
        self.recognition_request = None
        self.recognition_task = None
        self.audio_tap_block = None
        self.recognition_handler = None
        self.refresh_controls()

    def clear_transcript(self) -> None:
        self.committed_lines = []
        self.current_partial_line = ""
        self.render_transcript()

    def poll_ui_queue(self) -> None:
        while True:
            try:
                kind, payload = self.ui_queue.get_nowait()
            except queue.Empty:
                break

            if kind == "speech_auth":
                self.speech_authorization_status = int(payload)
                self.update_permission_labels()
                self.refresh_controls()
            elif kind == "microphone_auth":
                self.microphone_authorization_status = 3 if bool(payload) else 2
                self.update_permission_labels()
                self.refresh_controls()
            elif kind == "draft":
                self.current_partial_line = str(payload)
                self.status_var.set("Status: streaming partial result")
                self.render_transcript()
            elif kind == "final":
                self.commit_final_text(str(payload))
            elif kind == "error":
                self.awaiting_final_result = False
                self.cancel_pending_force_finalize()
                self.cleanup_recognition(cancel_task=True)
                self.status_var.set("Status: recognition error")
                messagebox.showerror("Apple Speech Error", str(payload))

        self.root.after(100, self.poll_ui_queue)

    def set_transcript(self, text: str) -> None:
        self.transcript_text.configure(state=tk.NORMAL)
        self.transcript_text.delete("1.0", tk.END)
        self.transcript_text.insert(tk.END, text)
        self.transcript_text.configure(state=tk.DISABLED)

    def render_transcript(self) -> None:
        lines = list(self.committed_lines)
        if self.current_partial_line:
            lines.append(self.current_partial_line)

        if not lines:
            self.set_transcript("")
            return

        self.set_transcript("\n".join(lines))

    def append_session_header(self) -> None:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        if self.committed_lines:
            self.committed_lines.append("")
        self.committed_lines.append(
            f"=== Recording {self.session_count} @ {timestamp} | {self.current_language_title()} ==="
        )

    def on_close(self) -> None:
        self.cancel_pending_force_finalize()
        self.cleanup_recognition(cancel_task=True)
        self.root.destroy()

    def run(self) -> None:
        self.root.mainloop()


def run_check() -> None:
    print(f"Python executable: {sys.executable}")
    missing_keys = missing_bundle_usage_description_keys()
    if missing_keys:
        print(bundle_runtime_error_message(missing_keys), file=sys.stderr)
        return

    speech_status = int(SFSpeechRecognizer.authorizationStatus())
    microphone_status = int(AVCaptureDevice.authorizationStatusForMediaType_(AVMediaTypeAudio))
    print(f"Speech permission: {speech_auth_label(speech_status)}")
    print(f"Microphone permission: {microphone_auth_label(microphone_status)}")
    print("Available languages:")
    for title, code in LANGUAGES:
        print(f"  - {title}: {code}")


def main() -> None:
    args = parse_args()
    missing_keys = missing_bundle_usage_description_keys()
    if missing_keys:
        print(bundle_runtime_error_message(missing_keys), file=sys.stderr)
        sys.exit(2)

    if args.check:
        run_check()
        return

    demo = AppleSpeechDemo()
    demo.run()


if __name__ == "__main__":
    main()
