# Quick Reference: Membership Type Updates

## Files Modified

### 1. `/lib/menu/membership_page.dart`
**What:** Replaced circular logo placeholders with professional icon-based badges

**Before:**
```dart
Container(
  width: 60,
  height: 60,
  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  child: const Center(
    child: Text(
      "NNBR",
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
    ),
  ),
)
```

**After:**
```dart
_buildMembershipBadge(title, color)  // Professional icon badge
```

**New Method:**
```dart
Widget _buildMembershipBadge(String type, Color color) {
  // Maps membership type to icon (⭐, ⭐, 👥, 🎓)
  // Returns 70x70 circular badge with shadow
}
```

---

### 2. `/lib/auth/register_profile_screen.dart`
**What:** Added membership type selection dropdown to signup flow

**Added Fields:**
```dart
String? selectedMembershipType;

final membershipOptions = [
  "1st Claim",
  "2nd Claim",
  "Social",
  "Full-Time Education",
];
```

**Added UI:**
```dart
const Text("Select Your Membership Type", ...)
DropdownButton<String>(
  value: selectedMembershipType,
  items: membershipOptions.map((String type) {
    return DropdownMenuItem<String>(
      value: type,
      child: Text(type),
    );
  }).toList(),
  onChanged: (String? newValue) {
    setState(() { selectedMembershipType = newValue; });
  },
)
```

**Added Validation:**
```dart
if (selectedMembershipType == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Please select a membership type")),
  );
  return;
}
```

---

### 3. `/lib/services/auth_service.dart`
**What:** Updated register method to accept and store membership_type

**Changed Signature:**
```dart
// Before
static Future<bool> register({
  required String email,
  required String password,
  required String fullName,
  required String dob,
  required String ukaNumber,
  required String club,
}) async {

// After
static Future<bool> register({
  required String email,
  required String password,
  required String fullName,
  required String dob,
  required String ukaNumber,
  required String club,
  required String membershipType,  // NEW
}) async {
```

**Database Insert:**
```dart
await _supabase.from('user_profiles').insert({
  "id": userId,
  "email": email,
  "full_name": fullName,
  "date_of_birth": dob,
  "uka_number": ukaNumber,
  "club": club,
  "membership_type": membershipType,  // NEW - Stored on registration
  "member_since": DateTime.now().toIso8601String(),
});
```

---

## Badge Icons by Membership Type

| Type | Icon | Color | Details |
|------|------|-------|---------|
| 1st Claim | ⭐ Star | #FFD700 Yellow | Standard membership, £30/year |
| 2nd Claim | ⭐ Half-star | #0055FF Blue | Secondary membership, £15/year |
| Social | 👥 People | Gray | Social/non-runners, £5/year |
| Full-Time Education | 🎓 School | #2E8B57 Green | Student membership, £15/year |

---

## User Registration Flow (Updated)

```
1. User navigates to signup
2. Enters: Name, Email, DOB, UKA Number, Password
3. ✨ NEW: Selects Membership Type from dropdown
4. Clicks "Create Account"
5. Validation checks:
   - All fields filled
   - Membership type selected (NEW)
6. Account created + membership_type stored in database
7. User logged in and taken to home screen
```

---

## Membership Page Display (Updated)

**Status Section:**
- Shows current membership type fetched from database
- Example: "Type: 1st Claim"

**Tiers Section:**
- 4 membership tier cards displayed
- Each has professional icon badge (not text "NNBR")
- Badges have drop shadows for depth
- All styling consistent with app dark theme

---

## Testing the Implementation

### To test registration with membership type:
1. Navigate to signup flow
2. Fill in all profile fields
3. Try clicking "Create Account" WITHOUT selecting membership type
   - ✅ Should see error: "Please select a membership type"
4. Select a membership type
5. Click "Create Account"
   - ✅ Account should be created
   - ✅ Check database: membership_type should be stored

### To test membership page display:
1. Log in with a registered user
2. Navigate to Menu → Membership & Renewal
3. Check "Your Membership" card
   - ✅ Should show user's membership_type from database
   - ✅ Should display correct member_since date
4. Check membership tier cards
   - ✅ Each badge should show the correct icon
   - ✅ Each badge should have the correct color
   - ✅ Shadow effects should be visible

---

## Notes for Future Development

### Payment Integration
- "Buy" buttons are currently placeholders
- Need to integrate with payment provider (Stripe, etc.)
- When user clicks "Buy" for a tier, should:
  1. Show payment form/redirect
  2. Process payment
  3. Update membership_type in database
  4. Update membership_status to "Active"

### Membership Changes
- Currently membership_type is set at registration and displayed from database
- To allow users to upgrade/downgrade membership:
  1. Add "Change Membership" feature in membership page
  2. Similar flow to registration (dropdown selection)
  3. Process payment if upgrading
  4. Update database membership_type and dates

### Admin Tools
- May want to add admin panel to:
  1. Manually set/change user membership_type
  2. View all users by membership tier
  3. Export membership lists
  4. Handle manual/offline registrations
