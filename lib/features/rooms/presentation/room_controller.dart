import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../data/rooms_repository.dart';
import '../domain/room.dart';

class RoomController extends ChangeNotifier {
  RoomController(this._repository, this.code);
  final RoomsRepository _repository;
  final String code;
  Room? room;
  List<Track> results = [];
  bool loading = true;
  bool actionLoading = false;
  String? error;
  io.Socket? _socket;
  Timer? _searchTimer;

  Future<void> initialize() async {
    try {
      room = await _repository.get(code);
      _socket = await _repository.connect(code, (updated) { room = updated; notifyListeners(); });
    } catch (exception) {
      error = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => _run(() => _repository.refresh(code));
  Future<void> vote() => _run(() => _repository.vote(code));
  Future<void> queue(String trackId) => _run(() => _repository.queue(code, trackId));
  Future<void> setThreshold(int value) => _run(() => _repository.setThreshold(code, value));

  void search(String query) {
    _searchTimer?.cancel();
    if (query.trim().length < 2) {
      results = [];
      notifyListeners();
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        results = await _repository.search(code, query.trim());
      } catch (exception) {
        error = exception.toString();
      }
      notifyListeners();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    actionLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      room = await _repository.get(code);
    } catch (exception) {
      error = exception.toString();
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> leave() => _repository.leave(code);

  @override
  void dispose() {
    _searchTimer?.cancel();
    _socket?.dispose();
    super.dispose();
  }
}
