# Treasure Hunt Smart Contract Documentation

## Overview

The Treasure Hunt smart contract is a blockchain-based treasure hunting game built on the Sui blockchain. It allows users to discover real-world treasures by scanning NFC tags or QR codes, earning NFT rewards for their discoveries.

## Architecture

### Core Components

1. **TreasureNFT** - NFT tokens representing discovered treasures
2. **HunterProfile** - User profiles tracking statistics and rank
3. **TreasureRegistry** - Central registry managing all available treasures
4. **TreasureInfo** - Metadata structure for treasures
5. **Event System** - Blockchain events for tracking activities

## Smart Contract Structure

### Module Declaration
```move
module 0x0::treasure_nft
```

### Dependencies
- `sui::object` - Object management
- `sui::tx_context` - Transaction context
- `std::string` - String operations
- `sui::url` - URL handling
- `sui::vec_map` - Key-value mapping

## Data Structures

### TreasureNFT
```move
public struct TreasureNFT has key, store {
    id: object::UID,
    treasure_id: string::String,
    name: string::String,
    description: string::String,
    image_url: url::Url,
    rarity: u8,
    location: string::String,
    coordinates: string::String,
    found_timestamp: u64,
    finder_address: address,
    metadata: vec_map::VecMap<string::String, string::String>
}
```

**Properties:**
- `id` - Unique object identifier
- `treasure_id` - Unique treasure identifier
- `name` - Human-readable treasure name
- `description` - Treasure description
- `image_url` - IPFS or HTTP URL for treasure image
- `rarity` - Rarity level (1=Common, 2=Rare, 3=Legendary)
- `location` - Human-readable location
- `coordinates` - GPS coordinates "lat,lng"
- `found_timestamp` - Discovery timestamp in milliseconds
- `finder_address` - Address of the discoverer
- `metadata` - Additional key-value properties

### HunterProfile
```move
public struct HunterProfile has key, store {
    id: object::UID,
    hunter_address: address,
    username: string::String,
    rank: u8,
    total_treasures_found: u64,
    streak_count: u64,
    last_hunt_timestamp: u64,
    score: u64,
    achievements: vector<string::String>
}
```

**Properties:**
- `hunter_address` - User's wallet address
- `username` - Chosen username
- `rank` - Hunter rank (1=Beginner, 2=Explorer, 3=Hunter, 4=Master)
- `total_treasures_found` - Total number of treasures discovered
- `streak_count` - Current consecutive hunting streak
- `last_hunt_timestamp` - Last treasure discovery time
- `score` - Total accumulated points
- `achievements` - List of unlocked achievements

### TreasureRegistry
```move
public struct TreasureRegistry has key {
    id: object::UID,
    treasures: vec_map::VecMap<string::String, TreasureInfo>,
    admin: address
}
```

**Properties:**
- `treasures` - Map of treasure ID to treasure information
- `admin` - Administrator address for treasure management

### TreasureInfo
```move
public struct TreasureInfo has store {
    treasure_id: string::String,
    name: string::String,
    description: string::String,
    image_url: string::String,
    rarity: u8,
    location: string::String,
    coordinates: string::String,
    is_found: bool,
    required_rank: u8,
    reward_points: u64
}
```

**Properties:**
- `is_found` - Whether treasure has been discovered
- `required_rank` - Minimum rank required to hunt this treasure
- `reward_points` - Points awarded for discovery

## Constants

### Error Codes
```move
const E_INVALID_TREASURE_ID: u64 = 1;
const E_TREASURE_ALREADY_FOUND: u64 = 2;
const E_INVALID_LOCATION: u64 = 3;
const E_INSUFFICIENT_RANK: u64 = 4;
```

### Rarity Levels
```move
const RARITY_RARE: u8 = 2;
const RARITY_LEGENDARY: u8 = 3;
```

### Hunter Ranks
```move
const RANK_BEGINNER: u8 = 1;
const RANK_EXPLORER: u8 = 2;
const RANK_HUNTER: u8 = 3;
const RANK_MASTER: u8 = 4;
```

## Core Functions

### Initialization
```move
fun init(ctx: &mut tx_context::TxContext)
```
- Creates and shares the main `TreasureRegistry`
- Sets the deployer as the admin
- Called automatically during contract deployment

### User Registration
```move
public fun create_hunter_profile(
    username: string::String,
    ctx: &mut tx_context::TxContext
)
```

**Purpose:** Creates a new hunter profile for a user

**Parameters:**
- `username` - Desired username (3-50 characters, alphanumeric + underscore)

**Effects:**
- Creates `HunterProfile` object owned by the caller
- Initializes with beginner rank and zero stats
- Emits `NewHunterEvent`

**Requirements:**
- Username must be valid format
- One profile per address

### Treasure Management (Admin Only)
```move
public fun add_treasure(
    registry: &mut TreasureRegistry,
    treasure_id: string::String,
    name: string::String,
    description: string::String,
    image_url: string::String,
    rarity: u8,
    location: string::String,
    coordinates: string::String,
    required_rank: u8,
    reward_points: u64,
    ctx: &mut tx_context::TxContext
)
```

**Purpose:** Adds a new treasure to the registry (admin only)

**Parameters:**
- `registry` - Mutable reference to TreasureRegistry
- `treasure_id` - Unique identifier for the treasure
- `name` - Display name
- `description` - Treasure description
- `image_url` - URL for treasure image
- `rarity` - Rarity level (1-3)
- `location` - Human-readable location
- `coordinates` - GPS coordinates "lat,lng"
- `required_rank` - Minimum rank to hunt (1-4)
- `reward_points` - Points awarded for discovery

**Requirements:**
- Caller must be registry admin
- Treasure ID must be unique
- Valid rarity and rank values

### Treasure Discovery
```move
public fun find_treasure(
    registry: &mut TreasureRegistry,
    profile: &mut HunterProfile,
    treasure_id: string::String,
    location_proof: string::String,
    clock: &sui::clock::Clock,
    ctx: &mut tx_context::TxContext
)
```

**Purpose:** Main function for discovering treasures

**Parameters:**
- `registry` - Mutable reference to TreasureRegistry
- `profile` - Mutable reference to user's HunterProfile
- `treasure_id` - ID of treasure being discovered
- `location_proof` - GPS coordinates for verification
- `clock` - System clock for timestamp

**Process:**
1. Validates treasure exists and hasn't been found
2. Checks user's rank meets requirements
3. Verifies location proof matches treasure coordinates
4. Marks treasure as found in registry
5. Creates and transfers TreasureNFT to user
6. Updates user's profile statistics
7. Checks for rank progression
8. Emits discovery and rank-up events

**Requirements:**
- Treasure must exist and be undiscovered
- User rank must meet minimum requirement
- Location proof must match treasure coordinates
- User must have sufficient gas for transaction

## Events

### TreasureFoundEvent
```move
public struct TreasureFoundEvent has copy, drop {
    treasure_id: string::String,
    finder: address,
    location: string::String,
    rarity: u8,
    timestamp: u64
}
```
Emitted when a treasure is successfully discovered.

### HunterRankUpEvent
```move
public struct HunterRankUpEvent has copy, drop {
    hunter: address,
    old_rank: u8,
    new_rank: u8,
    total_treasures: u64
}
```
Emitted when a hunter advances to a new rank.

### NewHunterEvent
```move
public struct NewHunterEvent has copy, drop {
    hunter: address,
    username: string::String,
    timestamp: u64
}
```
Emitted when a new hunter profile is created.

## Game Mechanics

### Rank Progression
Ranks are automatically updated based on total treasures found:

- **Beginner (1):** 0-4 treasures
- **Explorer (2):** 5-19 treasures  
- **Hunter (3):** 20-49 treasures
- **Master (4):** 50+ treasures

### Streak System
- Streak increments when hunting within 24 hours of last hunt
- Streak resets to 1 if more than 24 hours pass
- Used for gamification and potential future rewards

### Rarity System
Treasures have three rarity levels:
- **Common (1):** Basic treasures, lower rewards
- **Rare (2):** Moderate difficulty, medium rewards
- **Legendary (3):** High difficulty, maximum rewards

### Location Verification
- Uses "Proof of Physical Presence" (PoPP)
- Compares user's GPS coordinates with treasure location
- Prevents remote treasure hunting
- Tolerance typically set at 100-500 meters

## View Functions

### get_hunter_stats
```move
public fun get_hunter_stats(profile: &HunterProfile): (u8, u64, u64, u64)
```
Returns tuple of (rank, total_treasures_found, streak_count, score)

### get_treasure_details
```move
public fun get_treasure_details(nft: &TreasureNFT): (string::String, u8, string::String, u64)
```
Returns tuple of (name, rarity, location, found_timestamp)

## Security Features

### Access Control
- Treasure management restricted to admin address
- Users can only modify their own profiles
- NFT ownership automatically handled by Sui

### Validation
- Treasure ID uniqueness enforced
- Location verification prevents remote hunting
- Rank requirements prevent premature access
- Input validation on all parameters

### Anti-Fraud Measures
- One discovery per treasure globally
- Location proof verification
- Rank-based access control
- Immutable discovery records

## Integration Points

### Frontend Integration
- Call `create_hunter_profile` during user onboarding
- Use `find_treasure` when QR/NFC scanned with valid location
- Query profile stats for user dashboard
- Listen to events for real-time updates

### Backend Integration
- Monitor events for discovery tracking
- Validate location proofs before submission
- Manage treasure database synchronization
- Handle error cases and user feedback

## Error Handling

### Common Errors
- `E_INVALID_TREASURE_ID` - Treasure doesn't exist
- `E_TREASURE_ALREADY_FOUND` - Someone else found it first
- `E_INVALID_LOCATION` - User too far from treasure
- `E_INSUFFICIENT_RANK` - User rank too low

### Best Practices
- Always check treasure availability before attempting discovery
- Validate user location before calling contract
- Handle network failures gracefully
- Provide clear error messages to users

## Deployment Guide

### Prerequisites
1. Sui CLI installed and configured
2. Wallet with sufficient SUI for gas
3. Network access (testnet/mainnet)

### Deployment Steps
1. Compile the Move package:
   ```bash
   sui move build
   ```

2. Deploy to network:
   ```bash
   sui client publish --gas-budget 100000000
   ```

3. Save the package ID and TreasureRegistry object ID

4. Configure environment variables:
   ```bash
   export SUI_PACKAGE_ID="0x..."
   export TREASURE_REGISTRY_ID="0x..."
   ```

### Post-Deployment
1. Add initial treasures using `add_treasure`
2. Test with development accounts
3. Configure monitoring and analytics
4. Update frontend with contract addresses

## Testing

### Unit Tests
```bash
sui move test
```

### Integration Testing
1. Deploy to testnet
2. Create test hunter profiles
3. Add test treasures
4. Simulate discovery scenarios
5. Verify events and state changes

### Performance Testing
- Test with multiple concurrent discoveries
- Verify gas usage optimization
- Check event emission performance

## Future Enhancements

### Planned Features
- Achievement system implementation
- Treasure trading marketplace
- Seasonal events and limited treasures
- Reputation and leaderboard systems
- Cross-chain compatibility

### Scalability Considerations
- Optimize gas usage for large-scale adoption
- Implement treasure pagination
- Consider sharding for global deployment
- Event indexing optimization

## Support and Maintenance

### Monitoring
- Track discovery rates and user engagement
- Monitor gas costs and optimization opportunities
- Alert on unusual activity patterns

### Updates
- Plan for contract upgrades
- Version management strategy
- Data migration procedures

For technical support or questions about the contract implementation, please refer to the project repository or contact the development team.
