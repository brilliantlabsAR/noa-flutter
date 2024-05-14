# Testing checklist

The following tests describe various tests that are done pre-release. All of these tests are done manually as they require interacting with the real device, and system Bluetooth settings.

## First install permissions
- ✔️ Reject location permissions and test sending messages to Noa
- ✔️ Accept coarse location permissions and test sending messages to Noa
- ✔️ Reject bluetooth permissions and try to login

## Login screen
- ✔️ Open privacy policy link on login page
- ✔️ Open T&C link on login page
- ✔️ Open and close sign in with email window
- ✔️ Turn off internet and try all the sign in buttons
- ✔️ Sign in with Apple and check account info on account screen
- ✔️ Sign in with Google and check account info on account screen
- ✔️ Sign in with Email and check account info on account screen

## Pairing screen
- ✔️ Dock/un-dock Frame and ensure switching between "Bring your device close" and "Frame found"
- ✔️ Skip pairing during "Bring your device close"
- ✔️ Skip pairing during "Frame found"
- ✔️ Pair but cancel system popup
- ✔️ Pair and start DFU process but kill app half way and then restart DFU
- ✔️ Pair and start DFU process but kill Frame half way and then restart DFU
- ✔️ Pair and complete DFU. Ensure full setup process completes
- ✔️ Factory reset Frame and repair. On "Un-pair frame first", delete pairing from phone and try again
- ✔️ Delete pairing from phone and repair. On "Un-pair frame first", factory reset Frame and try again
- ✔️ Skip pairing during "Un-pair frame first"
- ✔️ Pair to an updated Frame but kill Frame half way
- ✔️ Pair to an updated Frame. Ensure full set up process completes

## Main screens
- ✔️ Tap to switch tabs between noa, tune and hack
- ✔️ Slide to switch tabs between noa, tune and hack
- ✔️ Open and close account page from noa, tune and hack pages

## Noa screen
- ✔️ Send noa requests and ensure the page populates as expected
- ✔️ Long press images to save to gallery: reject permission
- ✔️ Long press images to save to gallery: accept permission
- ✔️ Ensure message history is cleared after logout

## Tune screen
- ✔️ Set values in tune screen and restart app to check persistance
- ✔️ Ask Noa queries and check last message for correct Tune parameters
- ✔️ Logout and check that values are reset to defaults

## Hack screen
- ✔️ Ask Noa queries and ensure the logs scroll
- ✔️ Turn off internet connection and try to send requests
- ✔️ Dock app during responses, un-dock and ensure fresh queries work again
- ✔️ Dock/un-dock Frame and check state transitions are correct
- ✔️ Ask Noa queries and ensure no duplicate listeners created after multiple disconnects
- ✔️ Restart killed app and ensure reconnect works
- ✔️ Ask Noa queries and ensure no duplicate listeners created after reconnect
- ✔️ Factory reset Frame and check connection status is being rejected
- ✔️ Un-pair in system settings and check connection status being rejected
- ✔️ Copy bluetooth log on hack page by long pressing
- ✔️ Copy app log on hack page by long pressing

## Account screen
- ✔️ Privacy policy link on account page
- ✔️ T&C link on account page
- ✔️ Logout
- ⨯ Delete account: cancel confirmation
- ✔️ Delete account: accept confirmation

## Frame UI
- Wake up Frame with app open and ensure kiss emoji is shown
- Wait for 10 seconds to ensure sleep emoji is shown, and then 3 seconds later sleep
- Tap from kiss emoji to make a full Noa query
- Tap from sleep emoji to make a full Noa query
- Tap from reply state to make a full Noa query
- Wait 5 seconds in reply state to go to ready state
- Tap from every ready state emoji to a make a full Noa query
- Wait for 10 seconds in ready state to ensure sleep emoji is shown, and then 3 seconds later sleep
- Check wildcard frequency from ready state before going to sleep
- Double tap for image gen
- Turn off internet and ensure queries timeout correctly
- Turn off phone bluetooth and ensure Frame shows disconnected icon and goes to sleep

## Background mode
- Background app and lock phone and ensure full Noa queries work
- Kill-reopen app, background and lock phone and ensure full Noa queries work
- Turn off internet, test queries timeout, turn on internet and ensure queries work again
