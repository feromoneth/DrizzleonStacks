;; stream-core.clar
;; Core payment streaming contract for DrizzleonStacks.
;; Manages stream lifecycle: create, claim, cancel, renew, split.
;; Integrates with stream-conditions for release rules and stream-nft for positions.

;; ============================================================
;; Traits
;; ============================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; ============================================================
;; Constants
;; ============================================================

;; Minimum stream duration: 6 blocks (~1 hour)
(define-constant MIN_DURATION u6)

;; Stream statuses
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_PAUSED u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_CANCELLED u4)

;; Asset types
(define-constant ASSET_STX u1)
(define-constant ASSET_TOKEN u2)

;; Condition type constants (mirror stream-conditions)
(define-constant CONDITION_NONE u0)

;; Errors
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_STREAM_NOT_FOUND (err u1002))
(define-constant ERR_INVALID_AMOUNT (err u1003))
(define-constant ERR_INVALID_DURATION (err u1004))
(define-constant ERR_STREAM_NOT_ACTIVE (err u1005))
(define-constant ERR_NOTHING_TO_CLAIM (err u1006))
(define-constant ERR_TRANSFER_FAILED (err u1007))
(define-constant ERR_CONDITION_FAILED (err u1008))
(define-constant ERR_INVALID_RECIPIENT (err u1009))
(define-constant ERR_STREAM_EXPIRED (err u1010))
(define-constant ERR_INVALID_SPLIT (err u1011))
(define-constant ERR_SELF_STREAM (err u1012))
(define-constant ERR_NFT_MINT_FAILED (err u1013))
(define-constant ERR_NOT_NFT_CONTRACT (err u1014))

;; ============================================================
;; Data
;; ============================================================

(define-data-var stream-counter uint u0)

;; Core stream storage
(define-map streams uint
  {
    sender: principal,
    recipient: principal,
    total-amount: uint,
    claimed-amount: uint,
    start-block: uint,
    duration-blocks: uint,
    status: uint,
    asset-type: uint,
    token-contract: (optional principal),
    condition-id: uint,
    nft-id: uint
  }
)

;; ============================================================
;; Public Functions — Stream Lifecycle
;; ============================================================

;; Create an STX stream.
;; Locks STX in this contract. Mints an NFT position to the recipient.
;; Optionally attaches a condition from stream-conditions.
(define-public (create-stream
    (recipient principal)
    (total-amount uint)
    (duration-blocks uint)
    (condition-type uint)
    (condition-param-1 uint)
    (condition-param-2 uint)
    (condition-principal (optional principal))
  )
  (let
    (
      (stream-id (+ (var-get stream-counter) u1))
      (start-block burn-block-height)
    )
    ;; Validate inputs
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= duration-blocks MIN_DURATION) ERR_INVALID_DURATION)
    (asserts! (not (is-eq tx-sender recipient)) ERR_SELF_STREAM)

    ;; Lock STX in contract
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))

    ;; Create condition if type is not NONE
    (let
      (
        (cond-id (if (is-eq condition-type CONDITION_NONE)
                    u0
                    (unwrap! (contract-call? .stream-conditions create-condition
                      condition-type condition-param-1 condition-param-2
                      condition-principal stream-id tx-sender)
                      ERR_CONDITION_FAILED)))
        ;; Mint stream position NFT to recipient
        (nft-id (unwrap! (contract-call? .stream-nft mint-stream-nft recipient stream-id) ERR_NFT_MINT_FAILED))
      )
      ;; Store stream
      (map-set streams stream-id
        {
          sender: tx-sender,
          recipient: recipient,
          total-amount: total-amount,
          claimed-amount: u0,
          start-block: start-block,
          duration-blocks: duration-blocks,
          status: STATUS_ACTIVE,
          asset-type: ASSET_STX,
          token-contract: none,
          condition-id: cond-id,
          nft-id: nft-id
        }
      )
      (var-set stream-counter stream-id)
      (ok stream-id)
    )
  )
)

;; Create a SIP-010 token stream.
;; Transfers tokens from sender to this contract. Same lifecycle as STX stream.
(define-public (create-stream-token
    (recipient principal)
    (total-amount uint)
    (duration-blocks uint)
    (token <ft-trait>)
    (condition-type uint)
    (condition-param-1 uint)
    (condition-param-2 uint)
    (condition-principal (optional principal))
  )
  (let
    (
      (stream-id (+ (var-get stream-counter) u1))
      (start-block burn-block-height)
      (token-principal (contract-of token))
    )
    ;; Validate inputs
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= duration-blocks MIN_DURATION) ERR_INVALID_DURATION)
    (asserts! (not (is-eq tx-sender recipient)) ERR_SELF_STREAM)

    ;; Transfer tokens to this contract
    (try! (contract-call? token transfer total-amount tx-sender (as-contract tx-sender) none))

    ;; Create condition if type is not NONE
    (let
      (
        (cond-id (if (is-eq condition-type CONDITION_NONE)
                    u0
                    (unwrap! (contract-call? .stream-conditions create-condition
                      condition-type condition-param-1 condition-param-2
                      condition-principal stream-id tx-sender)
                      ERR_CONDITION_FAILED)))
        ;; Mint stream position NFT to recipient
        (nft-id (unwrap! (contract-call? .stream-nft mint-stream-nft recipient stream-id) ERR_NFT_MINT_FAILED))
      )
      ;; Store stream
      (map-set streams stream-id
        {
          sender: tx-sender,
          recipient: recipient,
          total-amount: total-amount,
          claimed-amount: u0,
          start-block: start-block,
          duration-blocks: duration-blocks,
          status: STATUS_ACTIVE,
          asset-type: ASSET_TOKEN,
          token-contract: (some token-principal),
          condition-id: cond-id,
          nft-id: nft-id
        }
      )
      (var-set stream-counter stream-id)
      (ok stream-id)
    )
  )
)

;; Claim vested STX from an active stream.
;; Caller must be the stream's current recipient.
(define-public (claim-stream (stream-id uint))
  (let
    (
      (stream (unwrap! (map-get? streams stream-id) ERR_STREAM_NOT_FOUND))
      (sender-addr (get sender stream))
      (recipient-addr (get recipient stream))
      (total (get total-amount stream))
      (claimed (get claimed-amount stream))
      (start (get start-block stream))
      (duration (get duration-blocks stream))
      (cond-id (get condition-id stream))
    )
    ;; Must be active
    (asserts! (is-eq (get status stream) STATUS_ACTIVE) ERR_STREAM_NOT_ACTIVE)
    ;; Caller must be recipient
    (asserts! (is-eq tx-sender recipient-addr) ERR_UNAUTHORIZED)

    ;; Check conditions (if any)
    (if (> cond-id u0)
      (try! (contract-call? .stream-conditions check-conditions cond-id))
      true
    )

    ;; Calculate claimable amount
    (let
      (
        (vested (calculate-vested total start duration))
        (claimable (- vested claimed))
      )
      (asserts! (> claimable u0) ERR_NOTHING_TO_CLAIM)

      ;; Transfer claimable STX to recipient
      (asserts! (is-eq (get asset-type stream) ASSET_STX) ERR_TRANSFER_FAILED)
      (try! (as-contract (stx-transfer? claimable tx-sender recipient-addr)))

      ;; Update stream state
      (let
        (
          (new-claimed (+ claimed claimable))
          (new-status (if (>= new-claimed total) STATUS_COMPLETED STATUS_ACTIVE))
        )
        (map-set streams stream-id
          (merge stream {
            claimed-amount: new-claimed,
            status: new-status
          })
        )
        (ok claimable)
      )
    )
  )
)

;; Claim vested SIP-010 tokens from an active stream.
(define-public (claim-stream-token (stream-id uint) (token <ft-trait>))
  (let
    (
      (stream (unwrap! (map-get? streams stream-id) ERR_STREAM_NOT_FOUND))
      (recipient-addr (get recipient stream))
      (total (get total-amount stream))
      (claimed (get claimed-amount stream))
      (start (get start-block stream))
      (duration (get duration-blocks stream))
      (cond-id (get condition-id stream))
    )
    ;; Must be active
    (asserts! (is-eq (get status stream) STATUS_ACTIVE) ERR_STREAM_NOT_ACTIVE)
    ;; Must be a token stream
    (asserts! (is-eq (get asset-type stream) ASSET_TOKEN) ERR_TRANSFER_FAILED)
    ;; Provided token must match stream's token-contract
    (asserts! (is-eq (some (contract-of token)) (get token-contract stream)) ERR_TRANSFER_FAILED)
    ;; Caller must be recipient
    (asserts! (is-eq tx-sender recipient-addr) ERR_UNAUTHORIZED)

    ;; Check conditions (if any)
    (if (> cond-id u0)
      (try! (contract-call? .stream-conditions check-conditions cond-id))
      true
    )

    ;; Calculate claimable amount
    (let
      (
        (vested (calculate-vested total start duration))
        (claimable (- vested claimed))
      )
      (asserts! (> claimable u0) ERR_NOTHING_TO_CLAIM)

      ;; Transfer claimable tokens to recipient
      (try! (as-contract (contract-call? token transfer claimable tx-sender recipient-addr none)))

      ;; Update stream state
      (let
        (
          (new-claimed (+ claimed claimable))
          (new-status (if (>= new-claimed total) STATUS_COMPLETED STATUS_ACTIVE))
        )
        (map-set streams stream-id
          (merge stream {
            claimed-amount: new-claimed,
            status: new-status
          })
        )
        (ok claimable)
      )
    )
  )
)

;; Cancel an active stream.
;; Vested-but-unclaimed goes to recipient. Remainder refunded to sender.
(define-public (cancel-stream (stream-id uint))
  (let
    (
      (stream (unwrap! (map-get? streams stream-id) ERR_STREAM_NOT_FOUND))
      (sender-addr (get sender stream))
      (recipient-addr (get recipient stream))
      (total (get total-amount stream))
      (claimed (get claimed-amount stream))
      (start (get start-block stream))
      (duration (get duration-blocks stream))
    )
    ;; Must be active
    (asserts! (is-eq (get status stream) STATUS_ACTIVE) ERR_STREAM_NOT_ACTIVE)
    ;; Only sender can cancel
    (asserts! (is-eq tx-sender sender-addr) ERR_UNAUTHORIZED)

    (let
      (
        (vested (calculate-vested total start duration))
        (unclaimed-vested (- vested claimed))
        (refund (- total vested))
      )
      ;; Transfer unclaimed vested to recipient
      (if (> unclaimed-vested u0)
        (begin
          (asserts! (is-eq (get asset-type stream) ASSET_STX) ERR_TRANSFER_FAILED)
          (try! (as-contract (stx-transfer? unclaimed-vested tx-sender recipient-addr)))
        )
        false
      )
      ;; Refund remaining to sender
      (if (> refund u0)
        (begin
          (asserts! (is-eq (get asset-type stream) ASSET_STX) ERR_TRANSFER_FAILED)
          (try! (as-contract (stx-transfer? refund tx-sender sender-addr)))
        )
        false
      )
      ;; Mark cancelled
      (map-set streams stream-id
        (merge stream {
          claimed-amount: (+ claimed unclaimed-vested),
          status: STATUS_CANCELLED
        })
      )
      (ok { recipient-amount: unclaimed-vested, sender-refund: refund })
    )
  )
)

;; Cancel a SIP-010 token stream.
(define-public (cancel-stream-token (stream-id uint) (token <ft-trait>))
  (let
    (
      (stream (unwrap! (map-get? streams stream-id) ERR_STREAM_NOT_FOUND))
      (sender-addr (get sender stream))
      (recipient-addr (get recipient stream))
      (total (get total-amount stream))
      (claimed (get claimed-amount stream))
      (start (get start-block stream))
      (duration (get duration-blocks stream))
    )
    ;; Must be active
    (asserts! (is-eq (get status stream) STATUS_ACTIVE) ERR_STREAM_NOT_ACTIVE)
    ;; Must be a token stream
    (asserts! (is-eq (get asset-type stream) ASSET_TOKEN) ERR_TRANSFER_FAILED)
    ;; Provided token must match stream's token-contract
    (asserts! (is-eq (some (contract-of token)) (get token-contract stream)) ERR_TRANSFER_FAILED)
    ;; Only sender can cancel
    (asserts! (is-eq tx-sender sender-addr) ERR_UNAUTHORIZED)

    (let
      (
        (vested (calculate-vested total start duration))
        (unclaimed-vested (- vested claimed))
        (refund (- total vested))
      )
      ;; Transfer unclaimed vested tokens to recipient
      (if (> unclaimed-vested u0)
        (try! (as-contract (contract-call? token transfer unclaimed-vested tx-sender recipient-addr none)))
        true
      )
      ;; Refund remaining tokens to sender
      (if (> refund u0)
        (try! (as-contract (contract-call? token transfer refund tx-sender sender-addr none)))
        true
      )
      ;; Mark cancelled
      (map-set streams stream-id
        (merge stream {
          claimed-amount: (+ claimed unclaimed-vested),
          status: STATUS_CANCELLED
        })
      )
      (ok { recipient-amount: unclaimed-vested, sender-refund: refund })
    )
  )
)

;; Renew an active stream: extend duration and top up amount.
;; Does not reset claimed-amount history.
(define-public (renew-stream
    (stream-id uint)
    (additional-amount uint)
    (additional-duration uint)
  )
  (let
    (
      (stream (unwrap! (map-get? streams stream-id) ERR_STREAM_NOT_FOUND))
      (sender-addr (get sender stream))
    )
    ;; Must be active
    (asserts! (is-eq (get status stream) STATUS_ACTIVE) ERR_STREAM_NOT_ACTIVE)
    ;; Only sender can renew
    (asserts! (is-eq tx-sender sender-addr) ERR_UNAUTHORIZED)
    ;; Must add something
    (asserts! (or (> additional-amount u0) (> additional-duration u0)) ERR_INVALID_AMOUNT)

    ;; Must be STX stream
    (asserts! (is-eq (get asset-type stream) ASSET_STX) ERR_TRANSFER_FAILED)

    ;; Lock additional STX if adding funds
    (if (> additional-amount u0)
      (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
      true
    )

    ;; Update stream
    (map-set streams stream-id
      (merge stream {
        total-amount: (+ (get total-amount stream) additional-amount),
        duration-blocks: (+ (get duration-blocks stream) additional-duration)
      })
    )
    (ok true)
  )
)

;; Renew a SIP-010 token stream.
(define-public (renew-stream-token
    (stream-id uint)
    (additional-amount uint)
    (additional-duration uint)
    (token <ft-trait>)
  )
  (let
    (
      (stream (unwrap! (map-get? streams stream-id) ERR_STREAM_NOT_FOUND))
      (sender-addr (get sender stream))
    )
    ;; Must be active
    (asserts! (is-eq (get status stream) STATUS_ACTIVE) ERR_STREAM_NOT_ACTIVE)
    ;; Must be a token stream
    (asserts! (is-eq (get asset-type stream) ASSET_TOKEN) ERR_TRANSFER_FAILED)
    ;; Provided token must match stream's token-contract
    (asserts! (is-eq (some (contract-of token)) (get token-contract stream)) ERR_TRANSFER_FAILED)
    ;; Only sender can renew
    (asserts! (is-eq tx-sender sender-addr) ERR_UNAUTHORIZED)
    ;; Must add something
    (asserts! (or (> additional-amount u0) (> additional-duration u0)) ERR_INVALID_AMOUNT)

    ;; Lock additional tokens if adding funds
    (if (> additional-amount u0)
      (try! (contract-call? token transfer additional-amount tx-sender (as-contract tx-sender) none))
      true
    )

    ;; Update stream
    (map-set streams stream-id
      (merge stream {
        total-amount: (+ (get total-amount stream) additional-amount),
        duration-blocks: (+ (get duration-blocks stream) additional-duration)
      })
    )
    (ok true)
  )
)

;; Update recipient — called by stream-nft contract on NFT transfer.
(define-public (update-recipient (stream-id uint) (new-recipient principal))
  (let
    (
      (stream (unwrap! (map-get? streams stream-id) ERR_STREAM_NOT_FOUND))
    )
    ;; Only the NFT contract can call this
    (asserts! (is-eq contract-caller .stream-nft) ERR_NOT_NFT_CONTRACT)
    ;; Update recipient
    (map-set streams stream-id
      (merge stream { recipient: new-recipient })
    )
    (ok true)
  )
)

;; ============================================================
;; Read-Only Functions
;; ============================================================

;; Get full stream record
(define-read-only (get-stream (stream-id uint))
  (map-get? streams stream-id)
)

;; Get the current stream counter
(define-read-only (get-stream-counter)
  (var-get stream-counter)
)

;; Calculate vested amount at the current burn-block-height
(define-read-only (get-vested-amount (stream-id uint))
  (match (map-get? streams stream-id)
    stream
      (ok (calculate-vested
        (get total-amount stream)
        (get start-block stream)
        (get duration-blocks stream)
      ))
    ERR_STREAM_NOT_FOUND
  )
)

;; Calculate claimable amount (vested minus claimed)
(define-read-only (get-claimable-amount (stream-id uint))
  (match (map-get? streams stream-id)
    stream
      (let
        (
          (vested (calculate-vested
            (get total-amount stream)
            (get start-block stream)
            (get duration-blocks stream)
          ))
          (claimed (get claimed-amount stream))
        )
        (ok (if (> vested claimed) (- vested claimed) u0))
      )
    ERR_STREAM_NOT_FOUND
  )
)

;; Project stream value at a future block.
;; Returns claimable-now and future-vesting at the target block.
(define-read-only (projected-value-at-block (stream-id uint) (target-block uint))
  (match (map-get? streams stream-id)
    stream
      (let
        (
          (total (get total-amount stream))
          (claimed (get claimed-amount stream))
          (start (get start-block stream))
          (duration (get duration-blocks stream))
          (vested-now (calculate-vested total start duration))
          (claimable-now (if (> vested-now claimed) (- vested-now claimed) u0))
          ;; Calculate vested at target block
          (target-elapsed (if (> target-block start)
                            (if (> (- target-block start) duration)
                              duration
                              (- target-block start))
                            u0))
          (vested-at-target (/ (* total target-elapsed) duration))
          (future-vesting (if (> vested-at-target vested-now)
                           (- vested-at-target vested-now)
                           u0))
        )
        (ok { claimable-now: claimable-now, future-vesting: future-vesting })
      )
    ERR_STREAM_NOT_FOUND
  )
)

;; ============================================================
;; Private Functions
;; ============================================================

;; Core vesting math:
;; elapsed = clamp(current_block - start_block, 0, duration)
;; vested = total_amount * elapsed / duration
(define-private (calculate-vested (total uint) (start uint) (duration uint))
  (let
    (
      (current burn-block-height)
      (elapsed (if (> current start)
                 (if (> (- current start) duration)
                   duration
                   (- current start))
                 u0))
    )
    (/ (* total elapsed) duration)
  )
)
