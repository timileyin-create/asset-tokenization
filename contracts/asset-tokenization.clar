;; title: Real-World Asset Tokenization Contract
;; summary: Implements fractionalized ownership of real-world assets with compliance features.
;; description: This contract allows for the creation, management, and transfer of tokenized real-world assets. It includes features for fractional ownership, compliance checks, and administrative controls to ensure regulatory adherence.

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-FUNDS (err u2))
(define-constant ERR-INVALID-ASSET (err u3))
(define-constant ERR-TRANSFER-FAILED (err u4))
(define-constant ERR-COMPLIANCE-CHECK-FAILED (err u5))
(define-constant ERR-INVALID-INPUT (err u6))

;; Validation functions
(define-private (is-valid-metadata-uri (uri (string-utf8 256)))
  (and 
    (> (len uri) u0)
    (<= (len uri) u256)
  )
)

(define-private (is-valid-asset-id (asset-id uint))
  (> asset-id u0)
)

(define-private (is-valid-principal (user principal))
  (not (is-eq user CONTRACT-OWNER))
)

;; Asset registry to track unique assets
(define-map asset-registry 
  {asset-id: uint} 
  {
    owner: principal,
    total-supply: uint,
    fractional-shares: uint,
    metadata-uri: (string-utf8 256),
    is-transferable: bool
  }
)

;; Compliance tracking map
(define-map compliance-status 
  {asset-id: uint, user: principal} 
  {is-approved: bool}
)

;; NFT to represent ownership shares
(define-non-fungible-token asset-ownership-token uint)

;; Create a new tokenized asset
(define-public (create-asset 
  (total-supply uint) 
  (fractional-shares uint)
  (metadata-uri (string-utf8 256))
)
  (begin 
    ;; Enhanced input validation
    (asserts! (> total-supply u0) ERR-INVALID-INPUT)
    (asserts! (> fractional-shares u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-metadata-uri metadata-uri) ERR-INVALID-INPUT)
    
    ;; Generate unique asset ID
    (let ((asset-id (var-get next-asset-id)))
      ;; Register the asset
      (map-set asset-registry 
        {asset-id: asset-id}
        {
          owner: tx-sender,
          total-supply: total-supply,
          fractional-shares: fractional-shares,
          metadata-uri: metadata-uri,
          is-transferable: true
        }
      )
      
      ;; Mint ownership NFT to creator
      (try! (nft-mint? asset-ownership-token asset-id tx-sender))
      
      ;; Increment asset ID
      (var-set next-asset-id (+ asset-id u1))
      
      ;; Return success with asset ID
      (ok asset-id)
    )
  )
)

;; Transfer fractional ownership
(define-public (transfer-fractional-ownership 
  (asset-id uint) 
  (to-principal principal) 
  (amount uint)
)
  (let (
    (asset (unwrap! (map-get? asset-registry {asset-id: asset-id}) ERR-INVALID-ASSET))
    (sender tx-sender)
  )
    ;; Enhanced input validation
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-principal to-principal) ERR-INVALID-INPUT)
    
    ;; Validate transferability and compliance
    (asserts! (get is-transferable asset) ERR-UNAUTHORIZED)
    (asserts! (is-compliance-check-passed asset-id to-principal) ERR-COMPLIANCE-CHECK-FAILED)
    
    ;; Perform transfer logic here (placeholder - would need actual token balance tracking)
    (try! (nft-transfer? asset-ownership-token asset-id sender to-principal))
    
    (ok true)
  )
)

;; Compliance check function
(define-private (is-compliance-check-passed 
  (asset-id uint) 
  (user principal)
) 
  (default-to false 
    (get is-approved 
      (map-get? compliance-status {asset-id: asset-id, user: user})
    )
  )
)

;; Admin function to approve compliance status
(define-public (set-compliance-status 
  (asset-id uint) 
  (user principal) 
  (is-approved bool)
)
  (begin
    ;; Enhanced input validation
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-principal user) ERR-INVALID-INPUT)
    
    ;; Only contract owner can set compliance status
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    (map-set compliance-status 
      {asset-id: asset-id, user: user} 
      {is-approved: is-approved}
    )
    
    (ok is-approved)
  )
)

;; Initialize next asset ID
(define-data-var next-asset-id uint u1)

;; Read-only function to get asset details
(define-read-only (get-asset-details (asset-id uint))
  (map-get? asset-registry {asset-id: asset-id})
)