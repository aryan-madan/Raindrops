<img src="./Sources/Resources/Logo.svg" alt="Raindrops Logo" width="120" />

# raindrops

(yes the name is inspired by airdrop)
a modern tool to share files between your mac and everything else.

## what is this?
it's a native mac app that spins up a server on your machine. this lets you share files with androids, windows pcs, or linux machines just by opening a link in their browser. basically airdrop, but for everyone.

## features
- **local transfer:** blazing fast sharing over your local wifi.
- **go public:** click one button to generate a public link (via cloudflare tunnel) to share files with anyone, anywhere in the world.
- **browser based:** no app needed on the receiving device.
- **native ui:** built with swiftui, looking right at home on macos.

## how it works
1. launch the app on your mac.
2. **local:** share the local ip address with devices on your wifi.
3. **public:** click "go public" to get a temporary web link for remote sharing.
4. drag and drop files to share, or download files people send you.

files land instantly in a `Raindrops` folder in your downloads.

## built with
- swift & swiftui
- vapor

enjoy (._.)/