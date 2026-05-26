import 'braincloud_service.dart';

/// Reasons the claim_username Cloud Code script can fail.
enum ClaimUsernameError { invalidName, nameTaken, unknown }

/// Exception thrown when a username claim fails.
class ClaimUsernameException implements Exception {
  ClaimUsernameException(
    this.error,
    this.message, {
    this.suggestions = const [],
  });
  final ClaimUsernameError error;
  final String message;

  /// Available alternates the server suggests (only populated when
  /// [error] is [ClaimUsernameError.nameTaken]).
  final List<String> suggestions;

  @override
  String toString() => message;
}

class UsernameService {
  UsernameService(this._bc);
  final BrainCloudService _bc;

  /// Atomically reserves [name] for the current player and updates their
  /// profile so leaderboard entries show it. Throws
  /// [ClaimUsernameException] if the name is taken or invalid.
  Future<String> claim(String name) async {
    final Map<String, dynamic> data;
    try {
      data = await _bc.runScript(
        'claim_username',
        scriptData: {
          'userName': name,
          // Cloud-code runtime variants don't all expose
          // `sessionProfileId` as a global; pass it explicitly so the
          // script can filter our own profile out of the duplicate
          // search after the update.
          'profileId': _bc.profileId,
        },
      );
    } catch (e) {
      // Non-script error (network, auth, etc.).
      throw ClaimUsernameException(ClaimUsernameError.unknown, e.toString());
    }

    final debug = data['debug'];
    if (debug != null) {
      // ignore: avoid_print
      print('claim_username debug: $debug');
    }

    // The script returns an embedded {status, reason_code, status_message,
    // suggestions?} envelope on failure instead of throwing — different
    // brainCloud builds handle script throws inconsistently, so returning
    // is portable.
    final scriptStatus = data['status'];
    final scriptReason = (data['reason_code'] ?? '').toString();
    if (scriptStatus is num &&
        scriptStatus != 200 &&
        scriptReason.isNotEmpty) {
      final message = (data['status_message'] ?? '').toString();
      final suggestions = _parseSuggestions(data['suggestions']);
      throw ClaimUsernameException(
        _errorFromReasonCode(scriptReason),
        message.isNotEmpty ? message : _defaultMessageFor(scriptReason),
        suggestions: suggestions,
      );
    }

    final claimed = (data['userName'] ?? name).toString();
    await _bc.updateUserName(claimed);
    return claimed;
  }

  List<String> _parseSuggestions(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  ClaimUsernameError _errorFromReasonCode(String code) {
    switch (code) {
      case 'NAME_TAKEN':
        return ClaimUsernameError.nameTaken;
      case 'INVALID_NAME':
        return ClaimUsernameError.invalidName;
      default:
        return ClaimUsernameError.unknown;
    }
  }

  String _defaultMessageFor(String reasonCode) {
    switch (reasonCode) {
      case 'NAME_TAKEN':
        return 'That name is already in use. Try another.';
      case 'INVALID_NAME':
        return 'Name must be 2–24 characters '
            '(letters, numbers, spaces, _ . - allowed).';
      default:
        return reasonCode;
    }
  }
}
