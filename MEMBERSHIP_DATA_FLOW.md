# Membership Type System - Complete Data Flow

## System Architecture Overview

```
USER REGISTRATION FLOW
├── 1. User fills profile form (RegisterProfileScreen)
│   ├── Name, Email, DOB, UKA Number, Password
│   └── ✨ Selects Membership Type (NEW)
│
├── 2. Form validation (RegisterProfileScreen)
│   ├── Check all fields filled
│   └── Check membership_type is selected (NEW)
│
├── 3. Call AuthService.register() (NEW parameter)
│   └── membershipType: selected value
│
├── 4. AuthService creates:
│   ├── Supabase Auth user
│   └── user_profiles table entry with membership_type (NEW)
│
└── 5. User logged in → Home screen
```

---

## Database Schema

### user_profiles Table

```sql
Column Name           Type        Description
─────────────────────────────────────────────────────
id                   uuid        User ID from Supabase Auth
email                varchar     User's email
full_name            varchar     User's full name
date_of_birth        date        User's DOB
uka_number           varchar     England Athletics member number
club                 varchar     Club name (e.g., "Northern Némésis Runners")
avatar_url           varchar     URL to user's profile avatar
member_since         timestamp   Date user registered (auto-set)
is_admin             boolean     Whether user is admin
admin_since          timestamp   When user became admin (if applicable)
membership_type      varchar     ✨ NEW: "1st Claim", "2nd Claim", "Social", or "Full-Time Education"
```

### Key Points
- `membership_type` is set at registration time
- `member_since` is auto-set to current date/time at registration
- Both values are immutable once set (unless updated via admin or upgrade flow)

---

## Membership Type Values

```dart
enum MembershipType {
  firstClaim,        // "1st Claim"
  secondClaim,       // "2nd Claim"
  social,            // "Social"
  fullTimeEducation, // "Full-Time Education"
}
```

### Mapping in Code
```dart
// In RegisterProfileScreen
final membershipOptions = [
  "1st Claim",
  "2nd Claim",
  "Social",
  "Full-Time Education",
];

// In membership page
case "1st Claim": icon = Icons.star; color = #FFD700; price = "£30"
case "2nd Claim": icon = Icons.star_half; color = #0055FF; price = "£15"
case "Social": icon = Icons.people; color = Gray; price = "£5"
case "Full-Time Education": icon = Icons.school; color = #2E8B57; price = "£15"
```

---

## Code Flow - Registration

### Step 1: User Selects Membership Type (UI)
**File:** `lib/auth/register_profile_screen.dart`

```dart
// State variable
String? selectedMembershipType;

// Dropdown widget
DropdownButton<String>(
  value: selectedMembershipType,
  items: membershipOptions.map(...).toList(),
  onChanged: (String? newValue) {
    setState(() { selectedMembershipType = newValue; });
  },
)
```

### Step 2: Validate Selection (UI)
**File:** `lib/auth/register_profile_screen.dart`

```dart
ElevatedButton(
  onPressed: loading ? null : () async {
    if (selectedMembershipType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a membership type"))
      );
      return;
    }
    // Continue with registration...
  },
  ...
)
```

### Step 3: Call Register with Membership Type
**File:** `lib/auth/register_profile_screen.dart`

```dart
final success = await AuthService.register(
  email: email.text.trim(),
  password: password.text.trim(),
  fullName: name.text.trim(),
  dob: dob.text.trim(),
  ukaNumber: uka.text.trim(),
  club: widget.selectedClub,
  membershipType: selectedMembershipType!,  // ✨ NEW
);
```

### Step 4: Store in Database
**File:** `lib/services/auth_service.dart`

```dart
static Future<bool> register({
  required String email,
  required String password,
  required String fullName,
  required String dob,
  required String ukaNumber,
  required String club,
  required String membershipType,  // ✨ NEW parameter
}) async {
  // ... create Supabase Auth user ...
  
  // Insert user_profiles row
  await _supabase.from('user_profiles').insert({
    "id": userId,
    "email": email,
    "full_name": fullName,
    "date_of_birth": dob,
    "uka_number": ukaNumber,
    "club": club,
    "membership_type": membershipType,  // ✨ Store in database
    "member_since": DateTime.now().toIso8601String(),
  });
  
  return true;
}
```

---

## Code Flow - Membership Page Display

### Step 1: Fetch User Data from Database
**File:** `lib/menu/membership_page.dart` - initState()

```dart
@override
void initState() {
  super.initState();
  _fetchMembershipData();
}

Future<void> _fetchMembershipData() async {
  try {
    final userId = _supabase.auth.currentUser?.id;
    final response = await _supabase
        .from('user_profiles')
        .select('member_since, membership_type')  // ✨ Fetch membership_type
        .eq('id', userId)
        .single();
    
    setState(() {
      _membershipType = response['membership_type'];  // ✨ Store in state
      _memberSince = response['member_since'];
    });
  } catch (e) {
    debugPrint('Error fetching membership data: $e');
  }
}
```

### Step 2: Display Status Card
**File:** `lib/menu/membership_page.dart` - _buildStatusCard()

```dart
Widget _buildStatusCard() {
  return Container(
    // ...
    child: Column(
      children: [
        _buildStatusRow("Status", "Active"),
        _buildStatusRow("Type", _membershipType ?? "Loading..."),  // ✨ Shows "1st Claim" etc.
        _buildStatusRow("Member Since", _formatDate(_memberSince)),
      ],
    ),
  );
}
```

Output in membership page:
```
┌─────────────────────────┐
│ YOUR MEMBERSHIP         │
├─────────────────────────┤
│ Status        Active    │
│ Type          1st Claim │ ← From database
│ Member Since  Jan 2024  │
└─────────────────────────┘
```

### Step 3: Display Membership Tier Badges
**File:** `lib/menu/membership_page.dart` - _membershipTierCard()

```dart
Widget _membershipTierCard({
  required Color color,
  required String title,  // "1st Claim", "2nd Claim", etc.
  required String subtitle,
  required String price,
  required String details,
  required Color buttonColor,
  required VoidCallback onBuy,
}) {
  return Container(
    // ...
    child: Row(
      children: [
        _buildMembershipBadge(title, color),  // ✨ NEW badge function
        // ... rest of card ...
      ],
    ),
  );
}

// ✨ NEW: Professional icon-based badges
Widget _buildMembershipBadge(String type, Color color) {
  IconData icon;
  switch (type) {
    case "1st Claim": icon = Icons.star; break;
    case "2nd Claim": icon = Icons.star_half; break;
    case "Social": icon = Icons.people; break;
    case "Full-Time Education": icon = Icons.school; break;
    default: icon = Icons.card_membership;
  }
  
  return Container(
    width: 70,
    height: 70,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Center(
      child: Icon(icon, color: Colors.white, size: 32),
    ),
  );
}
```

Visual output in membership page:
```
1st Claim                          Full-Time Education
┌────────────────────┐             ┌────────────────────┐
│  ⭐  | Standard    │             │  🎓  | Student     │
│     │ Membership  │             │     │ Membership  │
│     │ £30         │             │     │ £15         │
└────────────────────┘             └────────────────────┘
Yellow badge with star          Green badge with school icon
```

---

## Data Flow Diagram

```
┌─────────────────────────────────┐
│   RegisterProfileScreen         │
│  (User selects membership type) │
└────────────┬────────────────────┘
             │
             │ selectedMembershipType = "1st Claim"
             │
             ▼
┌─────────────────────────────────┐
│   Validation Check              │
│  (membership_type != null?)      │
└────────────┬────────────────────┘
             │
             │ ✓ Valid
             │
             ▼
┌─────────────────────────────────┐
│   AuthService.register()        │
│   + membershipType parameter    │
└────────────┬────────────────────┘
             │
             │ 1. Create Supabase Auth user
             │ 2. Insert into user_profiles with
             │    membership_type = "1st Claim"
             │
             ▼
┌──────────────────────────────────┐
│   Supabase Database              │
│   user_profiles table            │
│   ┌──────────────────────────┐   │
│   │ id: abc123              │   │
│   │ email: user@example.com │   │
│   │ full_name: John Doe     │   │
│   │ membership_type: 1st... │◄──┤─── ✨ Stored!
│   │ member_since: 2024-01.. │   │
│   └──────────────────────────┘   │
└──────────────────────────────────┘
             │
             │ Later: User navigates to Membership page
             │
             ▼
┌──────────────────────────────────┐
│   MembershipPage                 │
│   Fetches user data from DB      │
│   Gets membership_type = "1st..." │
└────────────┬─────────────────────┘
             │
             │ Display in two places:
             │
      ┌──────┴──────┐
      │             │
      ▼             ▼
┌──────────┐  ┌──────────────────────┐
│ Status   │  │ Membership Tiers     │
│ Card:    │  │ - 1st Claim ⭐      │ ← Badge icon from
│ Type:    │  │ - 2nd Claim ⭐       │   membership type
│ 1st Claim│  │ - Social 👥         │   in database
└──────────┘  │ - Full-Time 🎓      │
              └──────────────────────┘
```

---

## Example Database Query

### Create a new user with 1st Claim membership:

```sql
INSERT INTO user_profiles (
  id,
  email,
  full_name,
  date_of_birth,
  uka_number,
  club,
  membership_type,
  member_since
) VALUES (
  '550e8400-e29b-41d4-a716-446655440000',
  'runner@example.com',
  'Alice Runner',
  '1990-05-15',
  'EA123456',
  'Northern Némésis Runners',
  '1st Claim',                    -- ✨ NEW
  '2024-01-15T10:30:00Z'
);
```

### Fetch membership data for display:

```sql
SELECT 
  member_since,
  membership_type
FROM user_profiles
WHERE id = '550e8400-e29b-41d4-a716-446655440000';

-- Result:
-- member_since: 2024-01-15T10:30:00Z
-- membership_type: 1st Claim
```

---

## Summary

✅ **Membership type is now:**
- Captured during user registration
- Stored immediately in the database
- Displayed on the membership page
- Represented with professional icon badges
- Ready for future upgrade/downgrade features
