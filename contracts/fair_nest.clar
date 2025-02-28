;; FairNest Rental Marketplace Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-invalid-listing (err u101))
(define-constant err-already-booked (err u102))
(define-constant err-invalid-dates (err u103))
(define-constant err-payment-failed (err u104))

;; Data Variables
(define-data-var next-listing-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var platform-fee uint u25) ;; 2.5%

;; Data Maps
(define-map listings
  uint
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    price-per-night: uint,
    owner: principal,
    active: bool
  })

(define-map bookings
  uint 
  {
    listing-id: uint,
    guest: principal,
    start-date: uint,
    end-date: uint,
    total-price: uint,
    status: (string-ascii 20)
  })

(define-map reviews
  { listing-id: uint, reviewer: principal }
  {
    rating: uint,
    comment: (string-ascii 500),
    timestamp: uint
  })

;; Public Functions
(define-public (list-property (title (string-ascii 100)) (description (string-ascii 500)) (price-per-night uint) (owner principal))
  (let ((listing-id (var-get next-listing-id)))
    (if (is-eq tx-sender owner)
      (begin
        (map-set listings listing-id {
          title: title,
          description: description,
          price-per-night: price-per-night,
          owner: owner,
          active: true
        })
        (var-set next-listing-id (+ listing-id u1))
        (ok listing-id))
      err-not-owner)))

(define-public (book-property (listing-id uint) (start-date uint) (end-date uint))
  (let (
    (listing (unwrap! (map-get? listings listing-id) err-invalid-listing))
    (booking-id (var-get next-booking-id))
    (nights (- end-date start-date))
    (total-price (* nights (get price-per-night listing)))
  )
    (if (and 
      (get active listing)
      (> end-date start-date)
      (> start-date block-height))
      (begin
        (try! (stx-transfer? total-price tx-sender (get owner listing)))
        (map-set bookings booking-id {
          listing-id: listing-id,
          guest: tx-sender,
          start-date: start-date,
          end-date: end-date,
          total-price: total-price,
          status: "confirmed"
        })
        (var-set next-booking-id (+ booking-id u1))
        (ok booking-id))
      err-invalid-dates)))

(define-public (leave-review (listing-id uint) (rating uint) (comment (string-ascii 500)))
  (let ((booking (get-latest-booking listing-id tx-sender)))
    (if (and 
      (is-some booking)
      (<= rating u5))
      (begin
        (map-set reviews 
          { listing-id: listing-id, reviewer: tx-sender }
          {
            rating: rating,
            comment: comment,
            timestamp: block-height
          })
        (ok true))
      (err u105))))

;; Read Only Functions
(define-read-only (get-listing (listing-id uint))
  (map-get? listings listing-id))

(define-read-only (get-booking (booking-id uint))
  (map-get? bookings booking-id))

(define-read-only (get-latest-booking (listing-id uint) (guest principal))
  (map-get? bookings (- (var-get next-booking-id) u1)))

(define-read-only (get-review (listing-id uint) (reviewer principal))
  (map-get? reviews { listing-id: listing-id, reviewer: reviewer }))
