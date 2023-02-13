pragma solidity >=0.8.0;
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IERC5564Generator.sol";
import "./libs/EllipticCurve.sol";
import "./libs/BytesLib.sol";
import "./interfaces/IERC5564Registry.sol";

/// @notice Sample IERC5564Generator implementation for the secp256k1 curve.
contract SampleGenerator is EllipticCurve, Initializable, IERC5564Generator {
    IERC5564Registry public REGISTRY;

    function initialize(address _registry) external initializer {
        REGISTRY = IERC5564Registry(_registry);
    }

    /// @notice Sample implementation for parsing stealth keys on the secp256k1 curve.
    function stealthKeys(address registrant)
        public
        view
        override
        returns (
            uint256 spendingPubKeyX,
            uint256 spendingPubKeyY,
            uint256 viewingPubKeyX,
            uint256 viewingPubKeyY
        )
    {
        // Fetch the raw spending and viewing keys from the registry.
        (bytes memory spendingPubKey, bytes memory viewingPubKey) = REGISTRY
            .stealthKeys(registrant, address(this));

        // Parse the keys.
        assembly {
            spendingPubKeyX := mload(add(spendingPubKey, 0x20))
            spendingPubKeyY := mload(add(spendingPubKey, 0x40))
            viewingPubKeyX := mload(add(viewingPubKey, 0x20))
            viewingPubKeyY := mload(add(viewingPubKey, 0x40))
        }
    }

    /// @notice Sample implementation for generating stealth addresses for the secp256k1 curve.
    function generateStealthAddress(
        address registrant,
        bytes memory ephemeralPrivKey
    )
        external
        view
        override
        returns (
            address stealthAddress,
            bytes memory ephemeralPubKey,
            bytes memory sharedSecret,
            bytes32 viewTag
        )
    {
        // Get the ephemeral public key from the private key.
        {
            (uint256 x1, uint256 y1) = multiplyScalar(
                gx,
                gy,
                BytesLib.toUint256(ephemeralPrivKey, 0)
            );
            ephemeralPubKey = BytesLib.concat(
                BytesLib.toBytes(bytes32(x1)),
                BytesLib.toBytes(bytes32(y1))
            );
        }
        // Get user's parsed public keys.
        (
            uint256 spendingPubKeyX,
            uint256 spendingPubKeyY,
            uint256 viewingPubKeyX,
            uint256 viewingPubKeyY
        ) = stealthKeys(registrant);

        {
            // Generate shared secret from sender's private key and recipient's viewing key.
            (uint256 x1, uint256 y1) = multiplyScalar(
                viewingPubKeyX,
                viewingPubKeyY,
                uint256(BytesLib.toBytes32(ephemeralPrivKey, 0))
            );
            sharedSecret = BytesLib.concat(
                BytesLib.toBytes(bytes32(x1)),
                BytesLib.toBytes(bytes32(y1))
            );
        }
        bytes32 sharedSecretHash = keccak256(sharedSecret);

        // Generate a point from the hash of the shared secret
        bytes memory sharedSecretPoint;
        {
            // Generate shared secret from sender's private key and recipient's viewing key.
            (uint256 x1, uint256 y1) = multiplyScalar(
                gx,
                gy,
                uint256(bytes32(sharedSecretHash))
            );
            sharedSecretPoint = BytesLib.concat(
                BytesLib.toBytes(bytes32(x1)),
                BytesLib.toBytes(bytes32(y1))
            );
        }

        (uint256 a, uint256 b) = decomposeKey(sharedSecretPoint);
        // Generate sender's public key from their ephemeral private key.
        (a, b) = add(spendingPubKeyX, spendingPubKeyY, a, b);
        bytes memory stealthPubKey = BytesLib.concat(
            BytesLib.toBytes(bytes32(a)),
            BytesLib.toBytes(bytes32(b))
        );

        // Compute stealth address from the stealth public key.
        stealthAddress = pubkeyToAddress(stealthPubKey);
        // Generate view tag for enabling faster parsing for the recipient
        viewTag = BytesLib.toBytes32(
            BytesLib.concat(abi.encodePacked(stealthAddress), BytesLib.slice(BytesLib.toBytes(sharedSecretHash), 0, 12)), 0
        );
    }

    function pubkeyToAddress(bytes memory pub)
        public
        pure
        returns (address addr)
    {
        bytes32 hash = keccak256(pub);
        assembly {
            mstore(0, hash)
            addr := mload(0)
        }
    }
}
