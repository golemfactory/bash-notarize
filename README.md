# Bash-Notarize
#### Sign and Notarize your binaries with ease. :shipit:

### Pre-requisites

- An Apple developer account ([https://developer.apple.com/programs/enroll/](https://developer.apple.com/programs/enroll/))
- Signing Certificate ([https://developer.apple.com/support/certificates/](https://developer.apple.com/support/certificates/))
- App-specific password ([https://support.apple.com/en-us/HT204397](https://support.apple.com/en-us/HT204397))
- Team/Provider ID (if you have organization account)
	+ To get your provider ID:<br/>
	`xcrun altool --list-providers -u "AC_USERNAME" -p "AC_PASSWORD"`
	<br/>
	This will return to you something like;
	<br/>
| ProviderName | ProviderShortname | WWDRTeamID |
| --- | --- | --- |
| Example GmbH | ID-OF-TEAM | ID-OF-TEAM |

### Usage

- Clone the project
- Edit the entitlements.plist for your need.
	- More info: [https://developer.apple.com/documentation/bundleresources/entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)
- Call script with the proper arguments, like;
	<br/>
```
./main.sh \
	-a TEAM_ID \
	-u APPLE_ID \
	-p APP_SPECIFIC_PASSWORD \
	-s CERTIFICATE_NAME \
	-i BUNDLE_ID \
	-t TARGET_FILE \
	-e ./entitlements.plist
```

| Abbr | Full Flag | Description |
| --- | --- | --- |
| `-a` | `--asc_provider` | Team ID |
| `-u` | `--ac_username` | Apple ID |
| `-p` | `--ac_password` | App-specific Password (For security reasons call it better from keychain. More below.) |
| `-s` | `--app_sign` | Certificate Name |
| `-i` | `--bundle_id` | Give a bundle id to identify project easily. e.g. network.golem.app |
| `-t` | `--bundle_target` | Target tar.gz file of the project (dmg support will be added) |
| `-e` | `--entitlements` | Additional permission list |
| `-d` | `--sleep_delay` | Iteration time notarization check |

# Store App-Specific Password in Keychain

After having your app-specific password from Apple, it's better to keep it in keychain and call it from there.<br/>
(Note: This step may need your user password once when running the script)

To add your password;<br/>
`xcrun altool --store-password-in-keychain-item "TITLE_TO_CALL_PASSWORD_FROM_KEYCHAIN"
               -u "APPLE_ID"
               -p YOUR_APP_SPECIFIC_PASS`

Later you can use it in script with;

`-p @keychain:TITLE_TO_CALL_PASSWORD_FROM_KEYCHAIN \` e.g. `-p @keychain:AC_PASSWORD \`
