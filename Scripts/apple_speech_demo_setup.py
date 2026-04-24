from setuptools import setup


APP = ["apple_speech_demo.py"]
OPTIONS = {
    "argv_emulation": False,
    "plist": {
        "CFBundleDisplayName": "Apple Speech Demo",
        "CFBundleName": "Apple Speech Demo",
        "CFBundleIdentifier": "com.xuming.voiceinput.apple-speech-demo",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1",
        "LSMinimumSystemVersion": "14.0",
        "NSMicrophoneUsageDescription": "Apple Speech Demo needs microphone access to record your voice for transcription.",
        "NSSpeechRecognitionUsageDescription": "Apple Speech Demo needs speech recognition access to convert your voice into text.",
    },
}


setup(
    app=APP,
    options={"py2app": OPTIONS},
)
