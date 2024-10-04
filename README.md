# Arianee Project

<img src="https://github.com/Arianee/ArianeeMaster/raw/master/assets/cover.png" alt="Arianee Project" />

The **Arianee Project** is an independent and collaborative association dedicated to establishing a **global standard for the digital certification of valuable products**. This initiative includes a set of guidelines and tools collectively known as the **Arianee Protocol**.

## Learn More About the Arianee Protocol

- [Arianee Protocol Documentation](https://docs.arianee.org/docs/introduction)
- [Arianee Master Repository](https://github.com/Arianee/ArianeeMaster)
- [Official Arianee Website](https://arianee.org/)

## Security & Audits

In July 2024, a comprehensive audit of the circuits was conducted by [Veridise](https://veridise.com) to ensure the security and integrity of our privacy protocol. The full audit report is available in the repository for detailed insights and findings.

You can access the reports by following the links below:

- [VAR_Arianee_Circuits-Final](https://github.com/Arianee/arianee-sdk/blob/main/packages/privacy-circuits/VAR_Arianee_Circuits-Final.pdf)
- [VAR_Arianee_Contracts-Final](https://github.com/Arianee/ArianeeMaster/blob/1.5/VAR_Arianee_Contracts-Final.pdf)

## Installation of the Arianee Master Repository

To install the necessary components for the Arianee Master repository, follow these steps:

```bash
npm install
```

## Running Tests

To run the tests for the Arianee Master repository, use the following commands:

```bash
npm run ganache
npm run gsn
npm run test

# IssuerProxy tests
npm run test -- ./test/IssuerProxy.test.js (--compile-none to skip compilation)
# CreditNotePool tests
npm run test -- ./test/CreditNotePool.test.js (--compile-none to skip compilation)
```

This will start the necessary services and execute the test suite, ensuring everything is functioning correctly.