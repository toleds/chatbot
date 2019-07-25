import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dialogflow/dialogflow_v2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_recognition/speech_recognition.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatbot Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'DialogFlow Chatbot'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Widget> _messages = List<Widget>();
  TextEditingController _messageController = TextEditingController();

  AuthGoogle _authGoogle;
  Dialogflow _dialogflow;
  AudioPlayer _audioPlayer;

  SpeechRecognition _speechRecognition;
  bool _isListening = false;
  bool _isAvailable = false;

  _initDialogFlow() async {
    _authGoogle = await AuthGoogle(fileJson: "assets/credentials.json").build();
    // Select Language.ENGLISH or Language.SPANISH or others...
    _dialogflow = Dialogflow(authGoogle: _authGoogle, language: Language.english);

    _audioPlayer = AudioPlayer();
  }

  _tryToCorrectTheMessage(String message) {
    return message.replaceAll("\'", "\\'").replaceAll("\"", "\\\"");
  }

  _messageSend(String message) async {
    if (message == null || message.isEmpty) return;

    setState(() {
      _messages.insert(0, _message(message, true));
    });

    String response;
    String audioText;

    await _dialogflow.detectIntent(_tryToCorrectTheMessage(message)).then((resp) {
      response = resp.getMessage();
      audioText = resp.outputAudio;
    }).catchError((error) {
      response = error.toString();
      print(error.toString());
    });

    setState(() {
      _messages.insert(0, _message(response, false));
    });

    if (audioText != null) {
      var audio = base64.decode(audioText);
      final dir = await getTemporaryDirectory();

      final file = new File(
        '${dir.path}/audio.wav',
      );

      if (await file.exists()) {
        await file.delete();
      }

      await file.writeAsBytes(audio);
      await _audioPlayer.play(file.path, isLocal: true);
      _messageController.clear();
    }
  }

  _messageComposer() {
    return Container(
        padding: const EdgeInsets.only(left: 20.0),
        child: Row(children: <Widget>[
          Flexible(
              child: TextField(
                  onSubmitted: _messageSend,
                  controller: _messageController,
                  decoration: InputDecoration(
                      suffixIcon: IconButton(
                          icon: Icon(_isListening ? Icons.mic : Icons.mic_off),
                          onPressed: () {
                            _listen();
                          })))),
          Container(
              child: FlatButton.icon(
                  label: Text("Send"),
                  icon: Icon(Icons.send),
                  onPressed: () {
                    _messageSend(_messageController.text);
                  }))
        ]));
  }

  _messageDisplayer() {
    return Flexible(
      child: ListView.builder(
          padding: const EdgeInsets.all(20.0),
          reverse: true,
          itemCount: _messages.length,
          itemBuilder: (context, index) => _messages[index]),
    );
  }

  _messageBubble(String message, bool isOwnMessage) {
    return Row(
      mainAxisAlignment: isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: <Widget>[Flexible(flex: 1, child: Text("$message"))],
    );
  }

  _message(String message, bool isOwnMessage) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Container(
        child: _messageBubble(message, isOwnMessage),
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(color: Colors.blue[100]),
      ),
    );
  }

  _initSpeechRecognition() async {
    //Map<PermissionGroup, PermissionStatus> permissions =
    await PermissionHandler().requestPermissions([PermissionGroup.microphone, PermissionGroup.speech]);

    _speechRecognition = SpeechRecognition();
    _speechRecognition.setAvailabilityHandler((bool value) => setState(() => _isAvailable = value));
    _speechRecognition.setRecognitionStartedHandler(_onRecognitionStarted);
    _speechRecognition.setRecognitionResultHandler(_onRecognitionResult);
    _speechRecognition.setRecognitionCompleteHandler(_onRecognitionComplete);
    _speechRecognition.setErrorHandler(_errorHandler);
    _speechRecognition.activate().then((value) => setState(() => _isAvailable = value));
  }

  _onRecognitionStarted() => setState(() => _isListening = true);
  _onRecognitionResult(String text) => print("$text");
  _onRecognitionComplete(String text) {
    _messageSend(text);
    setState(() => _isListening = false);
  }

  _errorHandler() => _initSpeechRecognition();

  _listen() {
    if (_isAvailable && !_isListening) {
      _isListening = true;
      _speechRecognition.listen(locale: "en_US").then((value) => print('Value $value'));
    }
  }

  _buildSuggestionChips() {}

  @override
  void initState() {
    super.initState();
    _initDialogFlow();
    _initSpeechRecognition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(
            children: <Widget>[_messageDisplayer(), Divider(height: 10.0, color: Colors.black), _messageComposer()]));
  }
}
