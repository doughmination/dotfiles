#!/bin/sh

echo "Exporting Ubuntu package lists..."

# ---------------------------
# ALL MANUAL PACKAGES
# ---------------------------

echo "Querying manually installed packages..."
apt-mark showmanual > apt_dirty.txt


# ---------------------------
# FILTER GNOME
# ---------------------------

echo "Filtering GNOME packages..."
grep -vEi "gnome|gnome-shell|gdm3|nautilus|ubuntu-desktop|yaru|mutter" apt_dirty.txt > apt_nognome.txt


# ---------------------------
# FILTER UBUNTU META / DISTRO PACKAGES
# ---------------------------

echo "Filtering Ubuntu-specific packages..."
grep -vEi "ubuntu-|snapd|plymouth-theme|update-manager|software-center|whoopsie|popularity-contest" apt_nognome.txt > apt.txt


echo ""
echo "Done!"
echo ""
echo "Generated files:"
echo "  apt_dirty.txt"
echo "  apt_nognome.txt"
echo "  apt.txt"
echo ""
echo "Final reinstall list:"
echo "  apt.txt"
