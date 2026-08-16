class Room {
  const Room({required this.code, required this.status, required this.hostId, required this.skipThreshold, required this.currentTrack, required this.members, required this.voteCount});

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    code: json['code'] as String,
    status: json['status'] as String,
    hostId: json['hostId'] as String,
    skipThreshold: json['skipThreshold'] as int,
    currentTrack: json['currentTrack'] is Map ? Track.fromJson(Map<String, dynamic>.from(json['currentTrack'] as Map)) : null,
    members: (json['members'] as List<dynamic>).map((item) => RoomMember.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
    voteCount: json['voteCount'] as int
  );

  final String code;
  final String status;
  final String hostId;
  final int skipThreshold;
  final Track? currentTrack;
  final List<RoomMember> members;
  final int voteCount;
}

class RoomMember {
  const RoomMember({required this.name, required this.role});
  factory RoomMember.fromJson(Map<String, dynamic> json) => RoomMember(name: json['name'] as String, role: json['role'] as String);
  final String name;
  final String role;
}

class Track {
  const Track({required this.id, required this.name, required this.artist, required this.imageUrl});
  factory Track.fromJson(Map<String, dynamic> json) => Track(id: json['id'] as String, name: json['name'] as String, artist: json['artist'] as String, imageUrl: json['imageUrl'] as String?);
  final String id;
  final String name;
  final String artist;
  final String? imageUrl;
}
