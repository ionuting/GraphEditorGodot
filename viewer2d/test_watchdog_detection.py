import os
import time

# Creează un fișier de test pentru a vedea dacă watchdog-ul reacționează
test_file = "python/dxf/test_watchdog.txt"

print("Creez fișier de test pentru watchdog...")
with open(test_file, "w") as f:
    f.write("Test watchdog detection at " + str(time.time()))

print(f"Fișier creat: {test_file}")
print("Așteaptă 3 secunde să vedem dacă watchdog-ul detectează...")
time.sleep(3)

# Verifică dacă există log-uri sau indicii de activitate watchdog
if os.path.exists("reload_signal.json"):
    print("Fișier reload_signal.json există")
    with open("reload_signal.json", "r") as f:
        content = f.read()
        print(f"Conținut: {content}")
else:
    print("Nu există fișier reload_signal.json")

# Cleanup
if os.path.exists(test_file):
    os.remove(test_file)
    print("Fișier de test șters")