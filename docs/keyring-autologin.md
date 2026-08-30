# "Unlock keyring" at login — why it happens and how to fix it

If your Ubuntu goes straight to the desktop **without asking for a password**
(automatic login), the "keyring" — the safe where Chrome and other apps store
your passwords — cannot unlock itself, and some app will ask for it manually
at the worst moment.

Options, most to least recommended:

1. **Disable automatic login** (what Second Wind's hardware module offers):
   you type your password at startup, like on a Mac, and the keyring unlocks
   itself. This is the safe option.
2. **Leave it as is** and type the keyring password whenever an app asks.
3. Remove the keyring password ("Passwords and Keys" app → right-click
   "Login" → Change password → leave it empty).
   ⚠️ Not recommended: your passwords end up stored unencrypted.

Second Wind never applies option 3 for you.
