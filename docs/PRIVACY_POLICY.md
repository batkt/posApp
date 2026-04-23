# Posease — Privacy Policy

**Last updated:** April 23, 2026

This policy applies **only** to **Posease** — the Posease mobile POS application (Flutter package name `posease`). It does not cover other apps or websites unless we say so in writing.

**Service:** Point-of-sale and back-office features in Posease, connected to your organization’s account on the backend Posease uses.

This Privacy Policy explains how information is collected, used, stored, and protected when you use **Posease** and its related APIs (the “**Service**”). Posease is for **businesses and authorized staff**, not as a general consumer app.

By using Posease, you agree to this policy. If you do not agree, do not use Posease.

---

## 1. Who is responsible

The data controller for your use of Posease is:

- **Your organization** (the merchant or business that created the account and invited you), and/or  
- **The service operator** that provides Posease and hosting (replace with your legal entity name, address, and contact email).

For day-to-day questions about your account, contact your **employer or business administrator**. For privacy requests about the Service as a whole, contact the operator at the email listed on your organization’s dashboard or website.

---

## 2. Information we collect

### 2.1 Account and authentication

- Login identifiers (e.g. phone, username, or employee id as configured by your organization).  
- Authentication tokens or session data stored securely on the device (**flutter_secure_storage**) so you stay signed in until logout.  
- Where enabled, **biometric unlock** (**local_auth**) may be used **only on your device** to unlock Posease; biometric data is processed by your device’s OS and is not transmitted to our servers.

### 2.2 POS and business data (processed via the Service)

Examples include:

- Branch / organization identifiers, inventory, prices, carts, orders, payments, refunds, receipts, cash counts (“khaalt”), stock counts (“toololt”), reports, customer records (if your organization uses them), and audit-style transaction history.

This data is sent from Posease to **your organization’s backend** over HTTPS (for example `https://pos.zevtabs.mn` as configured in the Posease build, or another URL your deployment uses) so the Service can operate.

### 2.3 Device and diagnostics

We may collect limited technical information such as:

- Device model/OS (**device_info_plus**), app version (**package_info_plus**), and similar metadata needed for support and compatibility.

### 2.4 Payments and terminals

If you use integrated card terminals or payment SDKs (e.g. **PAX** / EPOS or other providers):

- Card processing is handled by **your payment provider / acquirer** according to their rules; Posease does not store full card numbers beyond what those providers require for PCI scope.  
- Operational messages (e.g. approval codes, receipt references) may appear in transaction records your organization stores.

### 2.5 Camera and barcode scanning

Posease may use the **camera** (**mobile_scanner**) to scan barcodes or QR codes for catalog and checkout. Images are used for decoding only as needed for that action unless your organization configures additional features.

### 2.6 Optional sharing

Posease features such as **share** (**share_plus**) or **printing/PDF** send content **only when you explicitly choose** to share or print.

---

## 3. How we use information

We use the information above to:

- Authenticate users and enforce permissions.  
- Process sales, inventory, and reporting as configured by your organization.  
- Provide support, security monitoring, and fraud prevention at a reasonable level.  
- Improve reliability and compatibility of Posease.

We do **not** sell your personal information. We do not use it for third-party advertising in Posease.

---

## 4. Legal bases (where applicable)

Depending on jurisdiction, processing may rely on:

- Performance of a contract with your organization.  
- Legitimate interests (secure operation of the Service, fraud prevention).  
- Legal obligation (e.g. tax or accounting retention as required by law).  
- Consent, where required (e.g. optional marketing—if offered separately).

---

## 5. Storage and security

- Traffic between Posease and servers should use **HTTPS/TLS**.  
- Sensitive tokens on device are stored using **secure storage** where supported by Posease.  
- Access to the Service should be protected by your organization’s policies (passwords, roles, branch access).

No method of transmission or storage is 100% secure; we aim for reasonable safeguards appropriate to Posease and the Service.

---

## 6. Retention

Retention of transaction and account data is determined by **your organization** and applicable law (e.g. accounting retention). Contact your administrator for deletion or export requests that concern business records.

---

## 7. Sharing with third parties

We may share data with:

- **Infrastructure and API providers** that host the Service.  
- **Payment processors and terminal vendors** when you initiate a payment.  
- **Authorities** when required by law or a lawful request.

We require subprocessors to protect data appropriately.

---

## 8. International transfers

If servers or vendors are located outside your country, we ensure appropriate safeguards where required (e.g. contracts or adequacy decisions).

---

## 9. Your rights

Depending on your location, you may have rights to **access**, **correct**, **delete**, **restrict**, or **export** personal data, and to **object** or **withdraw consent**. Many requests must be coordinated with **your employer** because business records may be controlled by the organization.

To exercise rights, contact your organization first, then the Service operator using the contact details published for your deployment.

---

## 10. Children’s privacy

The Service is **not directed at children** under 16 (or the age required in your jurisdiction). Do not register a child’s personal data unless your organization lawfully employs minors and complies with labor and privacy laws.

---

## 11. Changes

We may update this Privacy Policy for Posease. We will post the new version here and/or notify your organization. Continued use after changes means you accept the updated policy where allowed by law.

---

## 12. Contact

**Privacy inquiries:** *[Replace with privacy@yourdomain.com]*  
**Business address:** *[Replace with legal entity address]*  

---

*This document is provided as a template for your lawyers and compliance review. It does not constitute legal advice.*
