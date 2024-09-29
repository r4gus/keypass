const std = @import("std");

pub const Text = struct {
    auth_select_title: []const u8 = "--title=PassKeeZ: Authenticator Selection",
    auth_select: []const u8 = "--text=Do you want to use PassKeeZ as your authenticator?",
    user_presence_title: []const u8 = "--title=PassKeeZ: Authentication Request",
    user_presence: []const u8 = "--text=Would you like to login to the following page?:",
    user_presence_fallback: []const u8 = "Unknown Website",
    unlock_database_title: []const u8 = "--title=PassKeeZ: Unlock Database",
    unlock_database: []const u8 = "--text=Please enter your password",
    unlock_database_ok: []const u8 = "--ok-label=Unlock",
    database_decryption_failed_title: []const u8 = "--title=PassKeeZ: Wrong Password",
    database_decryption_failed: []const u8 = "--text=Credential database decryption failed",
    too_many_attempts_title: []const u8 = "--title=PassKeeZ: Authentication failed",
    too_many_attempts: []const u8 = "--text=Too many incorrect password attempts",
    no_database_title: []const u8 = "--title=PassKeeZ: No Database",
    no_database: []const u8 = "--text=Do you want to create a new passkey database?",
    new_database_title: []const u8 = "--title=PassKeeZ: New Database",
    new_database: []const u8 = "--text=Please choose a password",
    new_database_ok: []const u8 = "--ok-label=Create",
    database_created_title: []const u8 = "--title=PassKeeZ: Success",
    database_created: []const u8 = "--text=Database successfully create",
};

const english: Text = .{};
const german: Text = .{
    .auth_select_title = "--title=PassKeeZ: Authentikator Auswählen",
    .auth_select = "--text=Möchten Sie PassKeeZ als Ihren Authentikator verwenden?",
    .user_presence_title = "--title=PassKeeZ: Login Bestätigen",
    .user_presence = "--text=Möchten Sie sich bei der folgenden Seite einloggen?:",
    .user_presence_fallback = "Unknown Website",
    .unlock_database_title = "--title=PassKeeZ: Passwort-Datenbank Entschlüsseln",
    .unlock_database = "--text=Bitte geben Sie Ihr Passwort ein um die Passwort-Datenbank zu entschlüsseln",
    .unlock_database_ok = "--ok-label=Entschlüsseln",
    .database_decryption_failed_title = "--title=PassKeeZ: Falsches Passwort",
    .database_decryption_failed = "--text=Die Entschlüsselung der Datenbank ist fehlgeschlagen",
    .too_many_attempts_title = "--title=PassKeeZ: Authentifizierung Fehlgeschlagen",
    .too_many_attempts = "--text=Zu viele inkorrekte Passworteingaben",
    .no_database_title = "--title=PassKeeZ: Keine Passwort-Datenbank Gefunden",
    .no_database = "--text=Möchten Sie eine neue Passwort-Datenbank anlegen?",
    .new_database_title = "--title=PassKeeZ: Passwort-Datenbank Anlegen",
    .new_database = "--text=Bitte legen Sie ein Passwort fest",
    .new_database_ok = "--ok-label=Anlegen",
    .database_created_title = "--title=PassKeeZ: Passwort-Datenbank Angelegt",
    .database_created = "--text=Passwort-Datenbank erfolgreich angelget",
};

pub fn get(lang: []const u8) *const Text {
    if (std.mem.eql(u8, lang, "english")) {
        return &english;
    } else if (std.mem.eql(u8, lang, "german")) {
        return &german;
    } else {
        return &english;
    }
}
