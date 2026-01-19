/// Shared Types Module for Perpetuity Sui
/// 
/// This module defines types used across multiple modules.
/// Uses public helper functions to allow safe enum construction from other modules.

module perpetuity_sui::types {
    /// Binary option type for prediction markets
    /// Variants are private to the module; use helper functions to construct
    public enum Option has drop, copy, store {
        OptionA,
        OptionB,
    }

    /// Helper function to create OptionA
    /// Called by other modules to safely construct Option::OptionA
    public fun option_a(): Option {
        Option::OptionA
    }

    /// Helper function to create OptionB
    /// Called by other modules to safely construct Option::OptionB
    public fun option_b(): Option {
        Option::OptionB
    }

    /// Get complementary option
    /// OptionA <-> OptionB
    public fun complement(option: Option): Option {
        if (option == Option::OptionA) {
            Option::OptionB
        } else {
            Option::OptionA
        }
    }
}
