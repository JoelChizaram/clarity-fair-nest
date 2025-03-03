# FairNest: Decentralized Rental Marketplace

A decentralized marketplace for property rentals built on the Stacks blockchain using Clarity smart contracts.

## Features
- List properties for rent 
- Book properties
- Process rental payments
- Review system for both hosts and guests
- Dispute resolution mechanism

## Setup and Installation
1. Clone the repository
2. Install Clarinet (if not already installed)
3. Run `clarinet check` to verify contracts
4. Run `clarinet test` to run the test suite

## Usage Examples
```clarity
;; List a property
(contract-call? .fair-nest list-property 
  "Cozy Apartment" 
  "Modern 1BR in downtown" 
  u100000000 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Book a property
(contract-call? .fair-nest book-property 
  u1 
  u1670628000 
  u1671232800)

;; Leave a review
(contract-call? .fair-nest leave-review
  u1
  u5
  "Great experience!")
```

## Dependencies
- Clarity language
- Clarinet for testing and deployment
