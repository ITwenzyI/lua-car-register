# 🚔 kilian_lspd – Vehicle Registration System for LSPD

A fully functional and configurable vehicle registration system for police departments in ESX-based FiveM servers. Allows officers to assign license plates to unregistered or temporary vehicles using an intuitive menu interface.

---

## ✨ Features

- `/registercar` command (police only)
- ESX menu interface for selecting and registering vehicles
- View all unregistered vehicles or filter by plate / proximity
- Set **custom plates** (rank-restricted) or generate **random plates**
- Real-time plate syncing across all clients
- Plate updates in the database (`owned_vehicles`)
- Optional inventory sync (`inventories` table)
- Owner and officer in-game notifications
- Discord webhook logging for transparency

---

## 🧠 Usage

- Use `/registercar` as a police officer to open the menu
- Choose:
- 📋 View unregistered vehicles
- 🔍 Search by plate
- 📍 Show nearby vehicles (within 25 meters)
- Select a vehicle and choose:
- ✏️ Enter a custom plate (requires rank ≥ 8)
- 🔁 Generate a random plate
- All updates are synchronized and saved immediately

---

## 🔐 Permissions

Only users with `police` job can access this system.  
To limit **custom plate input**, rank check is used:

```lua
if playerData.job.grade < 8 then
 -- disallow custom plates
end

## 👤 Author
**Kilian**
