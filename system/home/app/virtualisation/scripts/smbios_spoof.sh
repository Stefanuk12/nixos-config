sudo cat /sys/firmware/dmi/tables/{smbios_entry_point,DMI} > smbios.bin

# DMI Type 1 - UUID Spoofing

uuid_offset=$(( $(hexdump -v -e '/1 "%02x"' smbios.bin | grep -abo -E '011b|011c' | head -n1 | cut -d: -f1) / 2 + 8 ))
uuidgen_hex=$(uuidgen -r | awk -F- '{print substr($1,7,2) substr($1,5,2) substr($1,3,2) substr($1,1,2) substr($2,3,2) substr($2,1,2) substr($3,3,2) substr($3,1,2) $4 $5}')
printf "$(echo $uuidgen_hex | sed 's/../\\x&/g')" | dd of=smbios.bin bs=1 seek=$uuid_offset count=16 conv=notrunc status=none

# DMI Type 1, 2, and 3 - Serial Number Spoofing

for serial in system_serial-number board_serial chassis_serial-number; do
  value=$(sudo cat /sys/class/dmi/id/${serial/product_/product_} 2>/dev/null)
  [[ -z "$value" ]] && continue
  spoof_serial="To Be Filled By O.E.M."
  LC_ALL=C sed -i "s/$value/$spoof_serial/g" smbios.bin
done

# DMI Type 17 - Serial Number Spoofing

for entry in /sys/firmware/dmi/entries/17-*/raw; do
  hex=$(sudo hexdump -v -e '/1 "%02x"' "$entry")
  string_hex=${hex:$((16#${hex:2:2} * 2))}
  serial=$(echo "$string_hex" | xxd -r -p | strings | grep -oE '[A-Z0-9]{8}' | head -n 1)
  spoof_serial="Unknown"
  if [[ -n "$serial" ]]; then
    LC_ALL=C sed -i "s/$serial/$spoof_serial/g" smbios.bin
  fi
done

mv smbios.bin ../libvirt/smbios.bin