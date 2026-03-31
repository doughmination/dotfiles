#!/bin/sh

echo "Exporting package lists..."

# ---------------------------
# PACMAN PACKAGES
# ---------------------------

echo "Querying official pacman packages..."
pacman -Qqen > pacman_dirty.txt

echo "Filtering GNOME packages..."
grep -vEi "gnome|mutter|gdm|nautilus|gnome-shell|gnome-control-center" pacman_dirty.txt > pacman_nognome.txt

echo "Filtering Nyarch packages..."
grep -vEi "nyarch|nyarchlinux|nyarch-" pacman_nognome.txt > pacman.txt


# ---------------------------
# AUR PACKAGES
# ---------------------------

echo "Querying AUR packages..."
pacman -Qqem > aur_dirty.txt

echo "Filtering GNOME packages..."
grep -vEi "gnome|mutter|gdm|nautilus|gnome-shell|gnome-control-center" aur_dirty.txt > aur_nognome.txt

echo "Filtering Nyarch packages..."
grep -vEi "nyarch|nyarchlinux|nyarch-" aur_nognome.txt > aur.txt


echo ""
echo "Done!"
echo ""
echo "Generated files:"
echo "  pacman_dirty.txt"
echo "  pacman_nognome.txt"
echo "  pacman.txt"
echo ""
echo "  aur_dirty.txt"
echo "  aur_nognome.txt"
echo "  aur.txt"
echo ""
echo "Final install lists:"
echo "  pacman.txt"
echo "  aur.txt"
