# 12-hour clock locale

`en_GB@12h` is a fork of glibc's `en_GB` locale that shows the time as 12-hour
with `AM`/`PM`, while keeping everything else British — `DD/MM/YY` date order,
`£`, Monday as first weekday.

Only the `LC_TIME` section differs from stock `en_GB`:

| Key          | stock `en_GB`               | `en_GB@12h`                    |
| ------------ | --------------------------- | ------------------------------ |
| `t_fmt`      | `%T`                        | `%I:%M:%S %p`                  |
| `d_t_fmt`    | `%a %d %b %Y %T %Z`         | `%a %d %b %Y %I:%M:%S %p %Z`   |
| `am_pm`      | `"am";"pm"`                 | `"AM";"PM"`                    |
| `t_fmt_ampm` | `%l:%M:%S %P %Z`            | `%I:%M:%S %p %Z`               |
| `date_fmt`   | `%a %e %b %H:%M:%S %Z %Y`   | `%a %e %b %I:%M:%S %p %Z %Y`   |

## Install on a fresh machine

```sh
sudo cp en_GB@12h /usr/share/i18n/locales/en_GB@12h
echo 'en_GB@12h UTF-8' | sudo tee -a /etc/locale.gen
sudo locale-gen
sudo cp locale.conf /etc/locale.conf     # sets LC_TIME=en_GB.UTF-8@12h
cp plasma-localerc ~/.config/            # same, for KDE apps
```

Log out and back in — `LC_TIME` is read at session start.

## Verify

```sh
$ LC_ALL=en_GB.UTF-8@12h date +%X    # 03:04:17 AM
$ LC_ALL=en_GB.UTF-8@12h date +%x    # 14/08/26   <- date order preserved
```

## Note

`locale-gen` names the generated locale `en_GB.UTF-8@12h` even though the
`locale.gen` line reads `en_GB@12h UTF-8`. Use the full `en_GB.UTF-8@12h` when
setting `LC_TIME`.

The bar and lock screens do **not** depend on this locale — waybar, hyprlock and
the SDDM theme format their own clocks (`%I` / `%p`, `Qt.formatTime`), so they
read 12-hour regardless. This locale is what makes `date`, GTK and Qt apps agree.
