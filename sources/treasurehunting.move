module 0x0::treasure_nft {
    use sui::object;
    use sui::tx_context;
    use std::string;
    use sui::url;
    use sui::vec_map;

    // Error codes
    const E_INVALID_TREASURE_ID: u64 = 1;
    const E_TREASURE_ALREADY_FOUND: u64 = 2;
    const E_INVALID_LOCATION: u64 = 3;
    const E_INSUFFICIENT_RANK: u64 = 4;

    // Treasure rarity levels
    const RARITY_RARE: u8 = 2;
    const RARITY_LEGENDARY: u8 = 3;

    // Hunter ranks
    const RANK_BEGINNER: u8 = 1;
    const RANK_EXPLORER: u8 = 2;
    const RANK_HUNTER: u8 = 3;
    const RANK_MASTER: u8 = 4;

    // Treasure NFT struct
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

    // Hunter Profile
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

    // Treasure Registry
    public struct TreasureRegistry has key {
        id: object::UID,
        treasures: vec_map::VecMap<string::String, TreasureInfo>,
        admin: address
    }

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

    // Events
    public struct TreasureFoundEvent has copy, drop {
        treasure_id: string::String,
        finder: address,
        location: string::String,
        rarity: u8,
        timestamp: u64
    }

    public struct HunterRankUpEvent has copy, drop {
        hunter: address,
        old_rank: u8,
        new_rank: u8,
        total_treasures: u64
    }

    public struct NewHunterEvent has copy, drop {
        hunter: address,
        username: string::String,
        timestamp: u64
    }

    // Initialize function
    fun init(ctx: &mut tx_context::TxContext) {
        let registry = TreasureRegistry {
            id: sui::object::new(ctx),
            treasures: sui::vec_map::empty(),
            admin: sui::tx_context::sender(ctx)
        };
        sui::transfer::share_object(registry);
    }

    // Create hunter profile
    #[allow(lint(self_transfer))]
    public fun create_hunter_profile(
        username: string::String,
        ctx: &mut tx_context::TxContext
    ) {
        let profile = HunterProfile {
            id: sui::object::new(ctx),
            hunter_address: sui::tx_context::sender(ctx),
            username,
            rank: RANK_BEGINNER,
            total_treasures_found: 0,
            streak_count: 0,
            last_hunt_timestamp: 0,
            score: 0,
            achievements: std::vector::empty()
        };

        sui::event::emit(NewHunterEvent {
            hunter: sui::tx_context::sender(ctx),
            username,
            timestamp: sui::tx_context::epoch_timestamp_ms(ctx)
        });

        sui::transfer::transfer(profile, sui::tx_context::sender(ctx));
    }

    // Add treasure to registry (admin only)
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
    ) {
        assert!(sui::tx_context::sender(ctx) == registry.admin, E_INVALID_TREASURE_ID);
        
        let treasure_info = TreasureInfo {
            treasure_id,
            name,
            description,
            image_url,
            rarity,
            location,
            coordinates,
            is_found: false,
            required_rank,
            reward_points
        };

        sui::vec_map::insert(&mut registry.treasures, treasure_id, treasure_info);
    }

    // Find treasure and mint NFT
    #[allow(lint(self_transfer))]
    public fun find_treasure(
        registry: &mut TreasureRegistry,
        profile: &mut HunterProfile,
        treasure_id: string::String,
        location_proof: string::String, // Proof of Physical Presence
        clock: &sui::clock::Clock,
        ctx: &mut tx_context::TxContext
    ) {
        // Verify treasure exists and hasn't been found
        assert!(sui::vec_map::contains(&registry.treasures, &treasure_id), E_INVALID_TREASURE_ID);
        
        let treasure_info = sui::vec_map::get_mut(&mut registry.treasures, &treasure_id);
        assert!(!treasure_info.is_found, E_TREASURE_ALREADY_FOUND);
        
        // Check hunter rank requirement
        assert!(profile.rank >= treasure_info.required_rank, E_INSUFFICIENT_RANK);
        
        // Verify location (simplified - in real implementation would verify GPS + NFC/QR)
        assert!(location_proof == treasure_info.coordinates, E_INVALID_LOCATION);

        // Mark treasure as found
        treasure_info.is_found = true;

        let current_time = sui::clock::timestamp_ms(clock);
        
        // Create metadata
        let mut metadata = sui::vec_map::empty<string::String, string::String>();
        sui::vec_map::insert(&mut metadata, std::string::utf8(b"rarity"), rarity_to_string(treasure_info.rarity));
        sui::vec_map::insert(&mut metadata, std::string::utf8(b"location"), treasure_info.location);
        sui::vec_map::insert(&mut metadata, std::string::utf8(b"found_date"), u64_to_string(current_time));

        // Convert string to bytes for URL creation
        let image_bytes = std::string::as_bytes(&treasure_info.image_url);
        
        // Mint NFT
        let nft = TreasureNFT {
            id: sui::object::new(ctx),
            treasure_id,
            name: treasure_info.name,
            description: treasure_info.description,
            image_url: sui::url::new_unsafe_from_bytes(*image_bytes),
            rarity: treasure_info.rarity,
            location: treasure_info.location,
            coordinates: treasure_info.coordinates,
            found_timestamp: current_time,
            finder_address: sui::tx_context::sender(ctx),
            metadata
        };

        // Update hunter profile
        profile.total_treasures_found = profile.total_treasures_found + 1;
        profile.score = profile.score + treasure_info.reward_points;
        
        // Update streak
        let time_diff = current_time - profile.last_hunt_timestamp;
        if (time_diff <= 86400000) { // 24 hours in milliseconds
            profile.streak_count = profile.streak_count + 1;
        } else {
            profile.streak_count = 1;
        };
        profile.last_hunt_timestamp = current_time;

        // Check for rank up
        let old_rank = profile.rank;
        update_hunter_rank(profile);
        
        if (profile.rank > old_rank) {
            sui::event::emit(HunterRankUpEvent {
                hunter: sui::tx_context::sender(ctx),
                old_rank,
                new_rank: profile.rank,
                total_treasures: profile.total_treasures_found
            });
        };

        // Emit treasure found event
        sui::event::emit(TreasureFoundEvent {
            treasure_id,
            finder: sui::tx_context::sender(ctx),
            location: treasure_info.location,
            rarity: treasure_info.rarity,
            timestamp: current_time
        });

        sui::transfer::transfer(nft, sui::tx_context::sender(ctx));
    }

    // Update hunter rank based on treasures found
    fun update_hunter_rank(profile: &mut HunterProfile) {
        if (profile.total_treasures_found >= 50) {
            profile.rank = RANK_MASTER;
        } else if (profile.total_treasures_found >= 20) {
            profile.rank = RANK_HUNTER;
        } else if (profile.total_treasures_found >= 5) {
            profile.rank = RANK_EXPLORER;
        }
        // Stays RANK_BEGINNER if < 5 treasures
    }

    // Helper functions
    fun rarity_to_string(rarity: u8): string::String {
        if (rarity == RARITY_LEGENDARY) {
            std::string::utf8(b"Legendary")
        } else if (rarity == RARITY_RARE) {
            std::string::utf8(b"Rare")
        } else {
            std::string::utf8(b"Common")
        }
    }

    fun u64_to_string(_value: u64): string::String {
        // Simplified conversion - in real implementation would use proper conversion
        std::string::utf8(b"timestamp")
    }

    // View functions
    public fun get_hunter_stats(profile: &HunterProfile): (u8, u64, u64, u64) {
        (profile.rank, profile.total_treasures_found, profile.streak_count, profile.score)
    }

    public fun get_treasure_details(nft: &TreasureNFT): (string::String, u8, string::String, u64) {
        (nft.name, nft.rarity, nft.location, nft.found_timestamp)
    }
}