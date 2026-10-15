module github.com/mohsen-niksirat/foxyvpn-desktop

go 1.26.0

replace firefox-vpn-client => github.com/UjuiUjuMandan/firefox-vpn-client v0.0.0-20260822124323-5b29eebc2766

require (
	firefox-vpn-client v0.0.0-20260822124323-5b29eebc2766
	golang.org/x/net v0.61.0
	golang.org/x/sys v0.49.0
)

require (
	golang.org/x/crypto v0.58.0 // indirect
	golang.org/x/text v0.43.0 // indirect
)
