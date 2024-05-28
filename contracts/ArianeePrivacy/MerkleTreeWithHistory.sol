// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IHasher {
    function MiMCSponge(uint256 xL_in, uint256 xR_in, uint256 k) external pure returns (uint256 xL, uint256 xR);
}

contract MerkleTreeWithHistory {
    uint256 public constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 public constant ZERO_VALUE = 1091521254540046781950077156238538356348959033991108648556163547643491462897; // = keccak256("arianee") % FIELD_SIZE
    IHasher public immutable hasher;

    uint32 public levels;

    // the following variables are made public for easier testing and debugging and
    // are not supposed to be accessed in regular code

    // filledSubtrees and roots could be bytes32[size], but using mappings makes it cheaper because
    // it removes index range check on every interaction
    mapping(uint256 => bytes32) public filledSubtrees;
    mapping(uint256 => bytes32) public roots;
    uint32 public constant ROOT_HISTORY_SIZE = 30;
    uint32 public currentRootIndex = 0;
    uint32 public nextIndex = 0;

    constructor(uint32 _levels, address _hasher) {
        require(_levels > 0, '_levels should be greater than zero');
        require(_levels < 32, '_levels should be less than 32');
        levels = _levels;
        hasher = IHasher(_hasher);

        for (uint32 i = 0; i < _levels; i++) {
            filledSubtrees[i] = zeros(i);
        }

        roots[0] = zeros(_levels - 1);
    }

    /**
    @dev Hash 2 tree leaves, returns MiMC(_left, _right)
  */
    function hashLeftRight(IHasher _hasher, bytes32 _left, bytes32 _right) public pure returns (bytes32) {
        require(uint256(_left) < FIELD_SIZE, '_left should be inside the field');
        require(uint256(_right) < FIELD_SIZE, '_right should be inside the field');
        uint256 R = uint256(_left);
        uint256 C = 0;
        (R, C) = _hasher.MiMCSponge(R, C, 0);
        R = addmod(R, uint256(_right), FIELD_SIZE);
        (R, C) = _hasher.MiMCSponge(R, C, 0);
        return bytes32(R);
    }

    function _insert(bytes32 _leaf) internal returns (uint32 index) {
        uint32 _nextIndex = nextIndex;
        require(_nextIndex != uint32(2) ** levels, 'Merkle tree is full. No more leaves can be added');
        uint32 currentIndex = _nextIndex;
        bytes32 currentLevelHash = _leaf;
        bytes32 left;
        bytes32 right;

        for (uint32 i = 0; i < levels; i++) {
            if (currentIndex % 2 == 0) {
                left = currentLevelHash;
                right = zeros(i);
                filledSubtrees[i] = currentLevelHash;
            } else {
                left = filledSubtrees[i];
                right = currentLevelHash;
            }
            currentLevelHash = hashLeftRight(hasher, left, right);
            currentIndex /= 2;
        }

        uint32 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        currentRootIndex = newRootIndex;
        roots[newRootIndex] = currentLevelHash;
        nextIndex = _nextIndex + 1;
        return _nextIndex;
    }

    /**
    @dev Whether the root is present in the root history
  */
    function isKnownRoot(bytes32 _root) public view returns (bool) {
        if (_root == 0) {
            return false;
        }
        uint32 _currentRootIndex = currentRootIndex;
        uint32 i = _currentRootIndex;
        do {
            if (_root == roots[i]) {
                return true;
            }
            if (i == 0) {
                i = ROOT_HISTORY_SIZE;
            }
            i--;
        } while (i != _currentRootIndex);
        return false;
    }

    /**
    @dev Returns the last root
  */
    function getLastRoot() public view returns (bytes32) {
        return roots[currentRootIndex];
    }

    /// @dev provides Zero (Empty) elements for a MiMC MerkleTree. Up to 32 levels
    function zeros(uint256 i) public pure returns (bytes32) {
        if (i == 0) return bytes32(0x0269c775826bf71ef2929fcab5dbcc0499f6f90cdc761333f54db63070592ef1);
        else if (i == 1) return bytes32(0x115563063a4d0e6c960b291821c71ddff0318a046d7030b0570b03c5174fad88);
        else if (i == 2) return bytes32(0x2be2b455e9fd91c8594da7eaf35cfc4c6198b4c3f27e46340e8f476e4cc6cb72);
        else if (i == 3) return bytes32(0x2c027c438cacfdbee2b7e838f6a7f2f116a48dd3ef491362bda9f83dae14dfcd);
        else if (i == 4) return bytes32(0x06cb0a4df16153f291eeb68b903810fe979b7dd9f334887e4251215af8afd608);
        else if (i == 5) return bytes32(0x250da57c5cae1d36700d6621d07e65ddae9713cd3af707a29df28d83429a7974);
        else if (i == 6) return bytes32(0x242ea4736a6694f4bd988ee7380764a9d639d823ebaf3112fc1e065bdc435375);
        else if (i == 7) return bytes32(0x198f135d37a7d88fedb617f6cab8940411de8c7ff43f211e0c8d000301a63e06);
        else if (i == 8) return bytes32(0x0a87e43d1c45af457a9bfb51c3cf14f07cf3485a3c1ccfcc0589d7877264a277);
        else if (i == 9) return bytes32(0x1de630c82ab7789820ab1fa17784accf01cbce0425b9f59ad5e15b256e9e908f);
        else if (i == 10) return bytes32(0x0790060571cf9ee25b441f4dbc10e128c7355755dfe1a746b4b84523c1388115);
        else if (i == 11) return bytes32(0x1c699b4b613b7e5b4135811becfea9100cdc18d1d0305e4dd6a1c3bde04d3656);
        else if (i == 12) return bytes32(0x00684b8d11ea2e8baab9709d571b502b8ab79f7ff62fab97875b29cb9cf3dd7a);
        else if (i == 13) return bytes32(0x012663bd13a8f01f88acbcb89bbf74a68349cce2939deb035bc80a1ec9014fcd);
        else if (i == 14) return bytes32(0x03b16e3bd3744be1db9bd99484f05f7e1243f9c0300936120ed3a38aea9f352d);
        else if (i == 15) return bytes32(0x2f375ba533cff24d557a4174583d7080a386a043c5f5c008c0202b1bf5c90fd8);
        else if (i == 16) return bytes32(0x29c41d5ac3a5cd779479aafde1fdadb9014eb5aee605be9c023f7ba3073de15c);
        else if (i == 17) return bytes32(0x2e212c95cf21c6d17434b55dbd571b266367d58d24db3efa0d91249533c20537);
        else if (i == 18) return bytes32(0x0b5f241a2ff4200f8c5fe5f75ea9d220be31740a07d14e14014f434ab86b7003);
        else if (i == 19) return bytes32(0x0a6d473442d8bd8a19415ecb08a4808ade2a437d55a24821835fe19ef220943a);
        else if (i == 20) return bytes32(0x2c838a2134fd4068d0716cfc52e6bc1b4031cb0e3623aa428ba15a348564a224);
        else if (i == 21) return bytes32(0x0168f1f4b1fde2e4af376f4fb9fc0f68bca8f20faeb5506f3eabfee46d889ee0);
        else if (i == 22) return bytes32(0x1c2d794f5a5fb54a9e9f943036719a39ee6c21ae8e35b49d82c3ed997b087778);
        else if (i == 23) return bytes32(0x0b6cf84774bf6a168859726ce6d977758a44297eeed4f500da01e5c2691a877d);
        else if (i == 24) return bytes32(0x24f5d3cb54181cbf9a67e246dd39f4bbad3caf5a70aec4029af604a2bd97688a);
        else if (i == 25) return bytes32(0x008f61547deba5182d019860e70b5873cacabddd243f78250fdb250c057d6418);
        else if (i == 26) return bytes32(0x1a731fc78852ad3587017f7d2fa7eea01ddf266f85fba6b5cc28fe7dfd93c9c0);
        else if (i == 27) return bytes32(0x08adab9419bf523eda8d046ce4dd906ee8973d00a4fb614a0ed7527330bf88c2);
        else if (i == 28) return bytes32(0x0470bf8ef24b4f8f4171edd2b47916fef4caa69c87fa843f1be0553c22914f6d);
        else if (i == 29) return bytes32(0x300ca9bb39bc9b7248f4033ee8085bc4e7c6e89b410bb0326db01a4f11baa73f);
        else if (i == 30) return bytes32(0x2331a6c3220ba1b932b8a473108e07395c42e6e173426a9bbf9594c37bc0f27c);
        else if (i == 31) return bytes32(0x1d112f31348e0fedfdb0b872663ae1ef9fdf5740f7576938a79b7bb2c870654b);
        else revert('Index out of bounds');
    }
}
