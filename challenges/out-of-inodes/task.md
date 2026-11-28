Customers can't log in to the shop. Its log says
`No space left on device` (see `journalctl -u shop`), but `df -h /srv`
shows the volume is only about half full.

Make logins work again, and leave `/srv` with at least half of its file
slots free so this doesn't come back next week.

- The shop keeps one file per login session in `/srv/shop/sessions`.
  A session idle for more than 24 hours has expired and can go.
  Customers who are logged in now must stay logged in.
- Product images in `/srv/shop/uploads` and the database dump in
  `/srv/shop/backup` must be kept.
- Clean up the volume. Don't resize, remount or replace it.
