;; FairNest Rental Marketplace Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-invalid-listing (err u101))
(define-constant err-already-booked (err u102))
(define-constant err-invalid-dates (err u103))
(define-constant err-payment-failed (err u104))
(define-constant err-booking-overlap (err u105))
(define-constant err-invalid-cancellation (err u106))

;; Data Variables
(define-data-var next-listing-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var platform-fee uint u25) ;; 2.5%

;; Events
(define-data-var last-event-id uint u0)

(define-map events 
  uint 
  {
    event-type: (string-ascii 20),
    listing-id: uint,
    user: principal,
    data: (string-ascii 256)
  })

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

;; Helper Functions
(define-private (emit-event (event-type (string-ascii 20)) (listing-id uint) (user principal) (data (string-ascii 256)))
  (let ((event-id (+ (var-get last-event-id) u1)))
    (map-set events event-id {
      event-type: event-type,
      listing-id: listing-id,
      user: user,
      data: data
    })
    (var-set last-event-id event-id)
    (ok event-id)))

(define-private (check-booking-overlap (listing-id uint) (start-date uint) (end-date uint))
  (let ((booking-id (- (var-get next-booking-id) u1)))
    (and 
      (>= booking-id u1)
      (let ((existing-booking (unwrap! (map-get? bookings booking-id) false)))
        (and
          (is-eq (get listing-id existing-booking) listing-id)
          (is-eq (get status existing-booking) "confirmed")
          (or
            (and (>= start-date (get start-date existing-booking))
                 (<= start-date (get end-date existing-booking)))
            (and (>= end-date (get start-date existing-booking))
                 (<= end-date (get end-date existing-booking)))
          ))))))

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
        (try! (emit-event "property-listed" listing-id owner title))
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
      (> start-date block-height)
      (not (check-booking-overlap listing-id start-date end-date)))
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
        (try! (emit-event "property-booked" listing-id tx-sender "booking-confirmed"))
        (ok booking-id))
      (if (check-booking-overlap listing-id start-date end-date)
        err-booking-overlap
        err-invalid-dates))))

(define-public (cancel-booking (booking-id uint))
  (let ((booking (unwrap! (map-get? bookings booking-id) err-invalid-listing)))
    (if (and
      (is-eq tx-sender (get guest booking))
      (> (get start-date booking) block-height)
      (is-eq (get status booking) "confirmed"))
      (begin
        (try! (stx-transfer? (get total-price booking) (get-listing-owner (get listing-id booking)) tx-sender))
        (map-set bookings booking-id (merge booking { status: "cancelled" }))
        (try! (emit-event "booking-cancelled" (get listing-id booking) tx-sender "booking-cancelled"))
        (ok true))
      err-invalid-cancellation)))

;; Read Only Functions
(define-read-only (get-listing (listing-id uint))
  (map-get? listings listing-id))

(define-read-only (get-booking (booking-id uint))
  (map-get? bookings booking-id))

(define-read-only (get-listing-owner (listing-id uint))
  (get owner (unwrap! (map-get? listings listing-id) tx-sender)))

(define-read-only (check-availability (listing-id uint) (start-date uint) (end-date uint))
  (if (check-booking-overlap listing-id start-date end-date)
    (err "Dates not available")
    (ok true)))

(define-read-only (get-latest-booking (listing-id uint) (guest principal))
  (map-get? bookings (- (var-get next-booking-id) u1)))

(define-read-only (get-review (listing-id uint) (reviewer principal))
  (map-get? reviews { listing-id: listing-id, reviewer: reviewer }))
