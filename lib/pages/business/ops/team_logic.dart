/// Parses `/business/team` whether `data` is a member list or
/// `{members, invites}`. Roles come from the server. If the server names the
/// actor but omits `assignable_roles`, the same owner/admin sets the backend
/// uses are filled in so Invite is reachable; the server still rejects a role
/// it does not allow.
class TeamSnapshot {
  const TeamSnapshot({
    required this.members,
    required this.invites,
    required this.assignableRoles,
    required this.myRole,
  });

  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> invites;
  final List<String> assignableRoles;
  final String myRole;
}

const teamAssignableByRole = <String, List<String>>{
  'owner': ['admin', 'finance', 'accountant', 'operations', 'developer'],
  'admin': ['finance', 'accountant', 'operations', 'developer'],
};

TeamSnapshot parseTeamResponse(Map<String, dynamic> response) {
  final meta = response['meta'] is Map
      ? Map<String, dynamic>.from(response['meta'] as Map)
      : <String, dynamic>{};
  final data = response['data'];
  List<Map<String, dynamic>> members = const [];
  List<Map<String, dynamic>> invites = const [];
  if (data is List) {
    members = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } else if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final rawMembers = map['members'] ?? map['team'];
    if (rawMembers is List) {
      members = rawMembers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final rawInvites = map['invites'] ?? map['pending'];
    if (rawInvites is List) {
      invites = rawInvites.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }
  final metaInvites = meta['invites'] ?? meta['pending_invites'];
  if (invites.isEmpty && metaInvites is List) {
    invites = metaInvites.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  final myRole = (meta['my_role'] ?? meta['role'] ?? '').toString();
  var assignable = ((meta['assignable_roles'] as List?) ?? const [])
      .map((e) => '$e')
      .where((e) => e.isNotEmpty && e != 'owner')
      .toList();
  if (assignable.isEmpty) {
    assignable = List<String>.from(teamAssignableByRole[myRole] ?? const []);
  }
  return TeamSnapshot(
    members: members,
    invites: invites,
    assignableRoles: assignable,
    myRole: myRole,
  );
}
