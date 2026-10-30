# OPNsense configuration export

`config-redacted.xml` is the firewall configuration exported from **System, Configuration, Backups**, with secrets removed.

## What was removed

| Item | Why |
|---|---|
| The `root` password hash | A hash can be attacked offline |
| The web interface certificate (`<crt>`) and its **private key** (`<prv>`) | The key lets anyone impersonate the firewall's web interface |

Each was replaced with the text `REDACTED`. The file still parses as valid XML.

## What is in it

Interface assignments (`em0` to `em3`), the four aliases, the nine firewall rules (LAN, DMZ, GUEST), and the Dnsmasq DHCP ranges. To read the rules quickly, search for `<description>` inside `OPNsense/Firewall/Filter/rules`.

## Handling a real export

Never commit a raw export. Before publishing one, search it for `password`, `prv`, `crt`, `secret`, `apikey`, `authorizedkeys`, `otp_seed` and `community`, and check for hostnames, usernames and addresses you do not want public.
