## outlet-control.sh

I created this bash script to make it easier to power on my deskfan and personal sized crockpot to heat my lunch. I assigned an alias `outlets` which I then provide an outlet number (1-4) and a power state (on/off). The device I am using is a Gosund WP9  (similiar product: https://amzn.to/3MiTbaK) flashed with tasomta (https://github.com/ct-Open-Source/tuya-convert) and using this template (https://templates.blakadder.com/gosund_WP9.html).

I included notifications to Telegram mostly as a reminder that my crockpot was turned on. Variables to be changed are: `TELEGRAM`, ip address in `URL` (cm subdirectory is need to issue commands), `chat_id` and `bot_id` both in the `PoststatustoTelegram` function.
