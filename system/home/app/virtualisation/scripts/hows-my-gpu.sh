echo "AMD Dedicated Graphics" | grep "AMD" --color=always
lspci -nnk | grep -iA3 "VGA compatible controller .* Navi" | grep "Kernel driver in use:" --color=always

echo "AMD Integrated Graphics" | grep "AMD" --color=always
lspci -nnk | grep -iA3 "VGA compatible controller .* Raphael" | grep "Kernel driver in use:" --color=always

echo ""
echo "Enable and disable the dedicated AMD GPU with dgpu-enable and dgpu-disable." | grep --color=always -E "dgpu-(enable|disable)"