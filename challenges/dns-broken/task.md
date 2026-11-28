Names in `shop.internal` don't resolve on this machine:

    ping -c 1 api.shop.internal
    ping: api.shop.internal: Name or service not known

Fix it so `ping -c 1 api.shop.internal` works, and every other
`shop.internal` name resolves too.

- Names must come from DNS. Don't put `shop.internal` names in `/etc/hosts`.
