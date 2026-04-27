# Login & Organization Data Documentation

> Authentication flow and Organization (Байгууллага) data retrieval

---

## 1. Login Function (`newterya`)

**Location:** `@/services/auth.js:61-123`

### Function Signature

```javascript
newterya(khereglech: {
  burtgeliinDugaar: string,  // Login ID/Username
  nuutsUg: string,           // Password
  namaigsana: boolean        // Remember me
}) => Promise<void>
```

### Login Flow

```
┌─────────────────┐
│  User Input     │
│  - Username     │
│  - Password     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Validation     │
│  Check fields   │
│  not empty      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  POST /ajiltan  │
│  Nevtrey        │
│  (Employee      │
│  Login API)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  POST /erkhiin  │
│  MedeelelAvya   │
│  (Get           │
│  Permissions)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Set Cookies:   │
│  - postoken     │
│  - baiguullagiinId
│  - salbariinId  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Redirect to    │
│  First Page     │
└─────────────────┘
```

### API Endpoints Used

| Endpoint               | Method | Description                  |
| ---------------------- | ------ | ---------------------------- |
| `/ajiltanNevtrey`      | POST   | Employee authentication      |
| `/erkhiinMedeelelAvya` | POST   | Get user permissions/modules |

### Login Response Data Structure

```javascript
{
  token: "jwt_token_string",           // JWT auth token
  result: {
    baiguullagiinId: "org_id",         // Organization ID
    salbaruud: ["branch_id_1", ...],   // Branches array
    // ... other employee data
  }
}
```

### Cookies Set After Login

| Cookie Name       | Value           | Max Age |
| ----------------- | --------------- | ------- |
| `postoken`        | JWT token       | 30 days |
| `baiguullagiinId` | Organization ID | 30 days |
| `salbariinId`     | Branch ID       | 30 days |

### Permission Data Stored

```javascript
// In localStorage
baiguulgiinErkhiinJagsaalt; // Permission list
baiguulgiinErkhiinJagsaaltGroup; // Permission groups
```

### Usage Example

```javascript
import { useAuth } from "services/auth";

function LoginPage() {
  const { newterya } = useAuth();

  const handleLogin = async (values) => {
    await newterya({
      burtgeliinDugaar: values.username,
      nuutsUg: values.password,
      namaigsana: values.rememberMe,
    });
  };
}
```

---

## 2. Get Organization Data (`useBaiguullaga`)

**Location:** `@/hooks/useBaiguullaga.js`

### Hook Signature

```javascript
useBaiguullaga(emiinSanId: string, token: string) => {
  baiguullaga: Object,      // Organization data
  baiguullagaMutate: Function  // Refresh function
}
```

### API Endpoint

```
GET /baiguullaga/:emiinSanId
```

### Organization Data Structure

```javascript
{
  _id: "org_id",
  ner: "Organization Name",           // Company name
  burtgeliinDugaar: "REG123",       // Registration number
  utas: "99119911",                  // Phone
  email: "contact@company.mn",         // Email
  khai: "Улаанбаатар",               // City
  duureg: "Баянгол",                 // District
  khoroo: "15-р хороо",              // Sub-district
  delgerenguiHayag: "Detail address", // Full address

  // Logo & Branding
  logo: "https://cdn.../logo.png",

  // Multi-branch settings
  salbaruud: [{
    _id: "branch_id",
    ner: "Branch Name",
    hayag: "Branch Address"
  }],

  // Receipt settings
  barimtiinTolgoi: "Company header text",
  barimtiinHervee: "Company footer text",

  // Tax settings (E-Barimt)
  ebarimt: {
    taxType: "VAT",
    cityTax: true
  }
}
```

### Usage Example

```javascript
import { useAuth } from "services/auth";
import useBaiguullaga from "hooks/useBaiguullaga";

function SettingsPage() {
  const { token, baiguullagiinId } = useAuth();
  const { baiguullaga, baiguullagaMutate } = useBaiguullaga(
    baiguullagiinId,
    token,
  );

  // Access organization data
  console.log(baiguullaga?.ner); // Company name
  console.log(baiguullaga?.logo); // Logo URL
  console.log(baiguullaga?.salbaruud); // Branches

  // Refresh data
  const refresh = () => baiguullagaMutate();
}
```

---

## 3. Auth Context Values

**Location:** `@/services/auth.js:59-141`

### Available in `useAuth()` Hook

| Property                          | Type     | Description               |
| --------------------------------- | -------- | ------------------------- |
| `newterya`                        | Function | Login function            |
| `garya`                           | Function | Logout function           |
| `token`                           | String   | Current JWT token         |
| `ajiltan`                         | Object   | Current employee data     |
| `ajiltanMutate`                   | Function | Refresh employee data     |
| `baiguullaga`                     | Object   | Organization data         |
| `baiguullagaMutate`               | Function | Refresh organization data |
| `baiguullagiinId`                 | String   | Organization ID           |
| `salbariinId`                     | String   | Current branch ID         |
| `setBaiguullagiinId`              | Function | Switch organization       |
| `setSalbariinId`                  | Function | Switch branch             |
| `baiguulgiinErkhiinJagsaalt`      | Array    | User permissions list     |
| `baiguulgiinErkhiinJagsaaltGroup` | Array    | Permission groups         |

---

## 4. Branch (Салбар) Handling

### Branch Selection Logic

```javascript
// From auth.js:100-104
var undsenSalbar = undefined;
if (!data?.result?.salbaruud) {
  // No branches - use org ID as branch
  undsenSalbar = data?.result?.baiguullagiinId;
} else if (data?.result?.salbaruud.length > 0) {
  // Has branches - use first branch
  undsenSalbar = data?.result?.salbaruud[0];
} else {
  undsenSalbar = data?.result?.baiguullagiinId;
}
```

### Switching Branches

```javascript
const { setSalbariinId } = useAuth();

// Switch to different branch
setSalbariinId("branch_id_here");
```

---

## 5. Error Handling

### Login Errors (`aldaaBarigch`)

**Location:** `@/services/uilchilgee.js:28-40`

| Error Type    | Message                                                        | Action          |
| ------------- | -------------------------------------------------------------- | --------------- |
| Network Error | "Интернэт холболт байхгүй байна. Офлайн горимд ажиллаж байна." | Alert only      |
| JWT Expired   | (Silent)                                                       | Redirect to `/` |
| API Error     | Server message                                                 | Alert display   |

### Common Login Error Messages

- `"Нэвтрэх нэр талбарыг бөглөнө үү"` - Username required
- `"Нууц үг талбарыг бөглөнө үү"` - Password required
- `"Хэрэглэгчийн мэдээлэл буруу байна"` - Invalid credentials
- `"Байгууллагын эрхийн тохиргоо хийгдээгүй байна"` - No permissions set

---

## 6. Complete Login Page Example

```javascript
import { useState } from "react";
import { useAuth } from "services/auth";

export default function Login() {
  const { newterya } = useAuth();
  const [form, setForm] = useState({
    burtgeliinDugaar: "",
    nuutsUg: "",
    namaigsana: false,
  });

  const handleSubmit = async (e) => {
    e.preventDefault();
    await newterya(form);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        placeholder="Нэвтрэх нэр"
        value={form.burtgeliinDugaar}
        onChange={(e) => setForm({ ...form, burtgeliinDugaar: e.target.value })}
      />
      <input
        type="password"
        placeholder="Нууц үг"
        value={form.nuutsUg}
        onChange={(e) => setForm({ ...form, nuutsUg: e.target.value })}
      />
      <label>
        <input
          type="checkbox"
          checked={form.namaigsana}
          onChange={(e) => setForm({ ...form, namaigsana: e.target.checked })}
        />
        Намайг сана
      </label>
      <button type="submit">Нэвтрэх</button>
    </form>
  );
}
```

---

## 7. Related Hooks

| Hook             | Purpose                   | File                        |
| ---------------- | ------------------------- | --------------------------- |
| `useAjiltan`     | Get current employee data | `@/hooks/useAjiltan.js`     |
| `useBaiguullaga` | Get organization data     | `@/hooks/useBaiguullaga.js` |
| `useAuth`        | Access auth context       | `@/services/auth.js`        |

---

## Key Files Reference

| File                        | Purpose                    |
| --------------------------- | -------------------------- |
| `@/services/auth.js`        | Auth context & login logic |
| `@/services/uilchilgee.js`  | API client with JWT        |
| `@/hooks/useBaiguullaga.js` | Organization data hook     |
| `@/hooks/useAjiltan.js`     | Employee data hook         |
| `@/pages/index.js`          | Login page                 |

API Endpoints & Domains
Production Domain
Domain URL
Main Domain https://pos.zevtabs.mn
Socket/WS wss://pos.zevtabs.mn/
API Endpoints
Service Environment Variable Production URL
Main API NEXT_PUBLIC_API_URL https://pos.zevtabs.mn/api
POS API NEXT_PUBLIC_POS_API_URL https://pos.zevtabs.mn/api
Socket.IO NEXT_PUBLIC_SOCKET wss://pos.zevtabs.mn/
Local Development IPs (Commented Out)
Main API: http://103.143.40.90:8080 or http://192.168.1.241:8080
POS API: http://103.143.40.66:8083 or http://192.168.1.241:8083
Socket.IO Configuration
javascript
// Socket path: /api/socket.io
// Transport: websocket
socketIOClient("wss://pos.zevtabs.mn/", {
path: "/api/socket.io",
transports: ["websocket"],
})
API Client Files
@/services/uilchilgee.js - Main API client (baseURL: NEXT_PUBLIC_API_URL)
@/services/posUilchilgee.js - POS-specific API client (baseURL: NEXT_PUBLIC_POS_API_URL)
Authentication Header
Authorization: bearer {JWT_TOKEN}
Content-type: application/json
