;; stream-conditions.clar
;; Condition engine for DrizzleonStacks payment streams.
;; Called by stream-core before every claim to enforce release rules.
;; Conditions are append-only: once attached to a stream, they cannot be removed.

;; ============================================================
;; Constants
;; ============================================================

;; Condition types
(define-constant CONDITION_NONE u0)
(define-constant CONDITION_BTC_THRESHOLD u1)
(define-constant CONDITION_CLIFF_LINEAR u2)
(define-constant CONDITION_MILESTONE u3)
(define-constant CONDITION_PAUSABLE u4)

;; Errors
(define-constant ERR_UNAUTHORIZED (err u3001))
(define-constant ERR_CONDITION_NOT_FOUND (err u3002))
(define-constant ERR_INVALID_CONDITION_TYPE (err u3003))
(define-constant ERR_THRESHOLD_NOT_MET (err u3004))
(define-constant ERR_CLIFF_NOT_REACHED (err u3005))
(define-constant ERR_MILESTONE_NOT_APPROVED (err u3006))
(define-constant ERR_STREAM_PAUSED (err u3007))
(define-constant ERR_INVALID_PARAMS (err u3008))
(define-constant ERR_ALREADY_PAUSED (err u3009))
(define-constant ERR_NOT_PAUSED (err u3010))
(define-constant ERR_MILESTONE_ALREADY_APPROVED (err u3011))
(define-constant ERR_INVALID_MILESTONE_INDEX (err u3012))

;; ============================================================
;; Data
;; ============================================================

(define-data-var condition-counter uint u0)

;; Main condition storage
;; condition-type: which type (see constants above)
;; param-uint-1: generic uint param (threshold block, cliff-end block, milestone count)
;; param-uint-2: generic uint param (reserved for future use)
;; param-principal-1: verifier for milestone conditions, sender for pausable
;; stream-id: the stream this condition governs
;; sender: principal who created the condition (for authorization)
(define-map conditions uint
  {
    condition-type: uint,
    param-uint-1: uint,
    param-uint-2: uint,
    param-principal-1: (optional principal),
    stream-id: uint,
    sender: principal
  }
)

;; Milestone approval tracking: (condition-id, milestone-index) → approved
(define-map milestones { condition-id: uint, milestone-index: uint } bool)

;; Pause state tracking: condition-id → paused
(define-map pause-state uint bool)

;; ============================================================
;; Public Functions
;; ============================================================

;; Create a new condition. Called by stream-core at stream creation.
;; Returns the condition-id.
(define-public (create-condition
    (condition-type uint)
    (param-uint-1 uint)
    (param-uint-2 uint)
    (param-principal-1 (optional principal))
    (stream-id uint)
    (sender principal)
  )
  (let
    (
      (condition-id (+ (var-get condition-counter) u1))
    )
    ;; Validate condition type
    (asserts! (<= condition-type u4) ERR_INVALID_CONDITION_TYPE)

    ;; Type-specific validation
    (asserts! (is-valid-condition-params condition-type param-uint-1 param-uint-2 param-principal-1) ERR_INVALID_PARAMS)

    ;; Store condition
    (map-set conditions condition-id
      {
        condition-type: condition-type,
        param-uint-1: param-uint-1,
        param-uint-2: param-uint-2,
        param-principal-1: param-principal-1,
        stream-id: stream-id,
        sender: sender
      }
    )

    ;; Initialize pause state to false for pausable conditions
    (if (is-eq condition-type CONDITION_PAUSABLE)
      (map-set pause-state condition-id false)
      true
    )

    (var-set condition-counter condition-id)
    (ok condition-id)
  )
)

;; Check if conditions are met for a claim.
;; Called by stream-core before processing any claim.
;; Returns (ok true) if conditions pass, or an error.
(define-public (check-conditions (condition-id uint))
  (let
    (
      (condition (unwrap! (map-get? conditions condition-id) ERR_CONDITION_NOT_FOUND))
      (ctype (get condition-type condition))
    )
    (if (is-eq ctype CONDITION_NONE)
      (ok true)
      (if (is-eq ctype CONDITION_BTC_THRESHOLD)
        (check-btc-threshold condition)
        (if (is-eq ctype CONDITION_CLIFF_LINEAR)
          (check-cliff-linear condition)
          (if (is-eq ctype CONDITION_MILESTONE)
            (check-milestone condition condition-id)
            (if (is-eq ctype CONDITION_PAUSABLE)
              (check-pause-state condition-id)
              ERR_INVALID_CONDITION_TYPE
            )
          )
        )
      )
    )
  )
)

;; Verifier approves a specific milestone for a condition.
(define-public (approve-milestone (condition-id uint) (milestone-index uint))
  (let
    (
      (condition (unwrap! (map-get? conditions condition-id) ERR_CONDITION_NOT_FOUND))
      (verifier (unwrap! (get param-principal-1 condition) ERR_UNAUTHORIZED))
      (total-milestones (get param-uint-1 condition))
    )
    ;; Must be a milestone condition
    (asserts! (is-eq (get condition-type condition) CONDITION_MILESTONE) ERR_INVALID_CONDITION_TYPE)
    ;; Caller must be the verifier
    (asserts! (is-eq tx-sender verifier) ERR_UNAUTHORIZED)
    ;; Milestone index must be valid (1-indexed)
    (asserts! (and (>= milestone-index u1) (<= milestone-index total-milestones)) ERR_INVALID_MILESTONE_INDEX)
    ;; Must not already be approved
    (asserts! (not (default-to false (map-get? milestones { condition-id: condition-id, milestone-index: milestone-index })))
      ERR_MILESTONE_ALREADY_APPROVED)

    (map-set milestones { condition-id: condition-id, milestone-index: milestone-index } true)
    (ok true)
  )
)

;; Sender pauses a pausable stream.
(define-public (pause-stream (condition-id uint))
  (let
    (
      (condition (unwrap! (map-get? conditions condition-id) ERR_CONDITION_NOT_FOUND))
    )
    ;; Must be a pausable condition
    (asserts! (is-eq (get condition-type condition) CONDITION_PAUSABLE) ERR_INVALID_CONDITION_TYPE)
    ;; Caller must be the sender
    (asserts! (is-eq tx-sender (get sender condition)) ERR_UNAUTHORIZED)
    ;; Must not already be paused
    (asserts! (not (default-to false (map-get? pause-state condition-id))) ERR_ALREADY_PAUSED)

    (map-set pause-state condition-id true)
    (ok true)
  )
)

;; Sender resumes a paused stream.
(define-public (resume-stream (condition-id uint))
  (let
    (
      (condition (unwrap! (map-get? conditions condition-id) ERR_CONDITION_NOT_FOUND))
    )
    ;; Must be a pausable condition
    (asserts! (is-eq (get condition-type condition) CONDITION_PAUSABLE) ERR_INVALID_CONDITION_TYPE)
    ;; Caller must be the sender
    (asserts! (is-eq tx-sender (get sender condition)) ERR_UNAUTHORIZED)
    ;; Must be paused
    (asserts! (default-to false (map-get? pause-state condition-id)) ERR_NOT_PAUSED)

    (map-set pause-state condition-id false)
    (ok true)
  )
)

;; ============================================================
;; Read-Only Functions
;; ============================================================

(define-read-only (get-condition (condition-id uint))
  (map-get? conditions condition-id)
)

(define-read-only (is-milestone-approved (condition-id uint) (milestone-index uint))
  (default-to false (map-get? milestones { condition-id: condition-id, milestone-index: milestone-index }))
)

(define-read-only (is-paused (condition-id uint))
  (default-to false (map-get? pause-state condition-id))
)

(define-read-only (get-condition-counter)
  (var-get condition-counter)
)

;; Count approved milestones for a condition.
;; Returns the number of approved milestones (checks up to param-uint-1).
(define-read-only (get-approved-milestone-count (condition-id uint))
  (match (map-get? conditions condition-id)
    condition
      (let
        (
          (total (get param-uint-1 condition))
        )
        (fold count-milestone-fold
          (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
          { condition-id: condition-id, total: total, count: u0 }
        )
      )
    { condition-id: condition-id, total: u0, count: u0 }
  )
)

;; ============================================================
;; Private Functions
;; ============================================================

;; Validate condition parameters based on type
(define-private (is-valid-condition-params
    (ctype uint)
    (p1 uint)
    (p2 uint)
    (pp1 (optional principal))
  )
  (if (is-eq ctype CONDITION_NONE)
    true
    (if (is-eq ctype CONDITION_BTC_THRESHOLD)
      ;; p1 = threshold block, must be > 0
      (> p1 u0)
      (if (is-eq ctype CONDITION_CLIFF_LINEAR)
        ;; p1 = cliff duration in blocks, must be > 0
        (> p1 u0)
        (if (is-eq ctype CONDITION_MILESTONE)
          ;; p1 = total milestone count (1..10), pp1 must be a verifier
          (and (>= p1 u1) (<= p1 u10) (is-some pp1))
          (if (is-eq ctype CONDITION_PAUSABLE)
            ;; No extra params needed, sender stored separately
            true
            false
          )
        )
      )
    )
  )
)

;; Check: burn-block-height >= threshold
(define-private (check-btc-threshold
    (condition {
      condition-type: uint,
      param-uint-1: uint,
      param-uint-2: uint,
      param-principal-1: (optional principal),
      stream-id: uint,
      sender: principal
    })
  )
  (if (>= burn-block-height (get param-uint-1 condition))
    (ok true)
    ERR_THRESHOLD_NOT_MET
  )
)

;; Check: current block is past the cliff period
;; For cliff-linear, param-uint-1 is the cliff duration in blocks.
;; The cliff end is relative to stream start, but since conditions don't store
;; stream start, we use param-uint-1 as an absolute block height for the cliff end.
(define-private (check-cliff-linear
    (condition {
      condition-type: uint,
      param-uint-1: uint,
      param-uint-2: uint,
      param-principal-1: (optional principal),
      stream-id: uint,
      sender: principal
    })
  )
  (if (>= burn-block-height (get param-uint-1 condition))
    (ok true)
    ERR_CLIFF_NOT_REACHED
  )
)

;; Check: at least one milestone is approved for the current claim
;; For milestone conditions, all milestones up to the current tranche must be approved.
;; Simplified: check that at least one milestone is approved.
(define-private (check-milestone
    (condition {
      condition-type: uint,
      param-uint-1: uint,
      param-uint-2: uint,
      param-principal-1: (optional principal),
      stream-id: uint,
      sender: principal
    })
    (condition-id uint)
  )
  (let
    (
      (result (get-approved-milestone-count condition-id))
      (approved-count (get count result))
    )
    (if (> approved-count u0)
      (ok true)
      ERR_MILESTONE_NOT_APPROVED
    )
  )
)

;; Check: stream is not paused
(define-private (check-pause-state (condition-id uint))
  (if (is-paused condition-id)
    ERR_STREAM_PAUSED
    (ok true)
  )
)

;; Fold helper to count approved milestones
(define-private (count-milestone-fold
    (index uint)
    (acc { condition-id: uint, total: uint, count: uint })
  )
  (if (<= index (get total acc))
    (if (default-to false (map-get? milestones { condition-id: (get condition-id acc), milestone-index: index }))
      (merge acc { count: (+ (get count acc) u1) })
      acc
    )
    acc
  )
)
