#!/usr/bin/env python3
"""
GNOME Keyring Unlocker for Nothing OS Rice
Unlocks the user's 'login' keyring via the Secret Service DBus API
without displaying any UI dialogs or prompts.
"""

import sys
import dbus

def unlock_keyring(password: str) -> bool:
    if not password:
        return False
    try:
        bus = dbus.SessionBus()
        service = bus.get_object('org.freedesktop.secrets', '/org/freedesktop/secrets')
        sec_iface = dbus.Interface(service, 'org.freedesktop.Secret.Service')
        internal = dbus.Interface(service, 'org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface')
        coll_path = dbus.ObjectPath('/org/freedesktop/secrets/collection/login')

        # Check if already unlocked
        coll_obj = bus.get_object('org.freedesktop.secrets', coll_path)
        props = dbus.Interface(coll_obj, 'org.freedesktop.DBus.Properties')
        if props.Get('org.freedesktop.Secret.Collection', 'Locked') == 0:
            return True

        # Open plain secret session
        output, session_path = sec_iface.OpenSession('plain', dbus.String('', variant_level=1))
        raw_bytes = [dbus.Byte(b) for b in password.encode('utf-8')]
        secret_struct = dbus.Struct(
            (session_path, dbus.Array([], signature='y'), dbus.Array(raw_bytes, signature='y'), 'text/plain; charset=utf8'),
            signature='oayays'
        )

        internal.UnlockWithMasterPassword(coll_path, secret_struct)
        return props.Get('org.freedesktop.Secret.Collection', 'Locked') == 0
    except Exception as e:
        sys.stderr.write(f"Keyring unlock error: {e}\n")
        return False

def main():
    if len(sys.argv) > 1:
        pwd = sys.argv[1]
    else:
        pwd = sys.stdin.read().strip()
    
    if unlock_keyring(pwd):
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
