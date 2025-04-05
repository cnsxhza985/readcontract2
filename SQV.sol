//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length)
        internal
        pure
        returns (string memory)
    {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

abstract contract ERC404 is Ownable {
    // Events
    event ERC20Transfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event ERC721Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // Errors
    error NotFound();
    error AlreadyExists();
    error InvalidRecipient();
    error InvalidSender();
    error UnsafeRecipient();
    error Unauthorized();

    // Metadata
    /// @dev Token name
    string public name;

    /// @dev Token symbol
    string public symbol;

    /// @dev Decimals for fractional representation
    uint8 public immutable decimals;

    /// @dev Total supply in fractionalized representation
    uint256 public immutable totalSupply;

    /// @dev Current mint counter, monotonically increasing to ensure accurate ownership
    uint256 public minted;

    // Mappings
    /// @dev Balance of user in fractional representation
    mapping(address => uint256) public balanceOf;

    /// @dev Allowance of user in fractional representation
    mapping(address => mapping(address => uint256)) public allowance;

    /// @dev Approval in native representaion
    mapping(uint256 => address) public getApproved;

    /// @dev Approval for all in native representation
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// @dev Owner of id in native representation
    mapping(uint256 => address) internal _ownerOf;

    /// @dev Array of owned ids in native representation
    mapping(address => uint256[]) internal _owned;

    /// @dev Tracks indices for the _owned mapping
    mapping(uint256 => uint256) internal _ownedIndex;

    /// @dev Addresses from minting / burning for gas savings (pairs, routers, etc)
    mapping(address => bool) public savingGasList;

    /// @dev Owner of id in native representation
    mapping(uint256 => address) public superNft;

    /// @dev Current mint counter, monotonically increasing to ensure accurate ownership
    uint256 public nextSuperNftId = 1;
    /// @dev Special NFT Cap
    uint256 public superNftMaxSupply;

    // 1-5: p1,p2,p3,p4,pf; 6: stakingNFTAddress
    mapping(uint8 => address) public projectAddress;
    mapping(address => RewardInfo) public rewardInfo;
    uint256 public constant CumulativeBurn = 20_000_000_000 * (10 ** 18);

    struct RewardInfo{
        uint256 earningsRecords;
        uint256 followersEarnings;
        uint256 feeRewards;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalNativeSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalNativeSupply * (10 ** decimals);

        superNftMaxSupply = 200;
    }

    function _isPoolAddress(address _addr) private view returns (bool) {
        return (_addr == projectAddress[1] || 
                _addr == projectAddress[2] || 
                _addr == projectAddress[3] || 
                _addr == projectAddress[4] || 
                _addr == projectAddress[5]);
    }

    function getOwnerLegendaryNFT(address _owner) public view returns (uint256[] memory result){
        uint256[] memory list = new uint256[](superNftMaxSupply);
        uint256 index;
        for(uint256 i = 1; i <= superNftMaxSupply; i++){
            if(superNft[i] == _owner){
                list[index] = i;
                index++;
            }
        }
        result = new uint256[](index);
        for (uint256 i; i < index; i++) {
            result[i] = list[i];
        }
    }

    function getOwnerDefaultNFTByPage(
        address _addr,
        uint256 page,
        uint256 pageSize
    ) public view returns (uint256[] memory result) {
        uint256[] memory defaultNfts = _owned[_addr];
        uint256 total = defaultNfts.length;

        require(page > 0, "Page number must be greater than zero");
	    require(pageSize > 0, "Page size must be greater than zero");

        uint256 start = (page - 1) * pageSize;
        require(start < total, "Page out of range");
        uint256 end = start + pageSize > total ? total : start + pageSize;

        result = new uint256[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = defaultNfts[i];
        }
    }

    function getOwnerDefaultNFT(address _addr) public view returns (uint256[] memory result){
        uint256[] memory defaultNfts = _owned[_addr];
        result = new uint256[](defaultNfts.length);
        uint256 index;

        for(uint256 i; i < defaultNfts.length; i++){
            result[index] = defaultNfts[i];
            index++;
        }
    }

    function setStakingNftAddr(address _stakingNFT) public onlyOwner {
        projectAddress[6] = _stakingNFT;
    }

    function setSavingGasList(address target, bool state) public onlyOwner {
        savingGasList[target] = state;
    }

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        if(id > 0 && id <= superNftMaxSupply){
            return owner = superNft[id];
        }
        owner = _ownerOf[id];
    }

    function tokenURI(uint256 id) public view virtual returns (string memory);

    function approve(
        address spender,
        uint256 amountOrId
    ) public virtual returns (bool) {
        if (amountOrId <= minted && amountOrId > 0) {
            address owner = (amountOrId <= superNftMaxSupply ? superNft[amountOrId] : _ownerOf[amountOrId]);
            if(owner == address(0))
                revert NotFound();
            if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) {
                revert Unauthorized();
            }

            getApproved[amountOrId] = spender;

            emit Approval(owner, spender, amountOrId);
        } else {
            allowance[msg.sender][spender] = amountOrId;

            emit Approval(msg.sender, spender, amountOrId);
        }

        return true;
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amountOrId
    ) public virtual {

        if (amountOrId <= minted) {
            if (from != ownerOf(amountOrId)) {
                revert InvalidSender();
            }

            if (to == address(0)) {
                revert InvalidRecipient();
            }

            if (
                msg.sender != from &&
                !isApprovedForAll[from][msg.sender] &&
                msg.sender != getApproved[amountOrId]
            ) {
                revert Unauthorized();
            }

            if(amountOrId <= superNftMaxSupply){
                superNft[amountOrId] = to;
            }else{
                balanceOf[from] -= _getUnit();
                unchecked {
                    balanceOf[to] += _getUnit();
                }
                _ownerOf[amountOrId] = to;

                delete getApproved[amountOrId];

                // update _owned for sender
                uint256 updatedId = _owned[from][_owned[from].length - 1];
                _owned[from][_ownedIndex[amountOrId]] = updatedId;
                // pop
                _owned[from].pop();
                // update index for the moved id
                _ownedIndex[updatedId] = _ownedIndex[amountOrId];
                // push token to to owned
                _owned[to].push(amountOrId);
                // update index for to owned
                _ownedIndex[amountOrId] = _owned[to].length - 1;
                emit ERC20Transfer(from, to, _getUnit());
            }
            emit Transfer(from, to, amountOrId);

        } else {
            uint256 allowed = allowance[from][msg.sender];

            if (allowed != type(uint256).max)
                allowance[from][msg.sender] = allowed - amountOrId;

            _transfer(from, to, amountOrId);
        }
    }

    /// @notice Function for fractional transfers
    function transfer(
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    /// @notice Function for native transfers with contract support
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            IERC721Receiver(to).onERC721Received(msg.sender, from, id, "") !=
            IERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Function for native transfers with contract support and callback data
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            IERC721Receiver(to).onERC721Received(msg.sender, from, id, data) !=
            IERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Internal function for fractional transfers
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 unit = _getUnit();
        uint256 balanceBeforeReceiver = balanceOf[to];

        if(_isPoolAddress(from)){
            balanceOf[from] -= amount;

            unchecked {
                balanceOf[to] += amount;
            }

            // Skip minting for certain addresses to save gas
            if (!savingGasList[to] && to != address(0)) {
                uint256 tokens_to_mint = (balanceOf[to] / unit) -
                    (balanceBeforeReceiver / unit);
                for (uint256 i = 0; i < tokens_to_mint; i++) {
                    _mint(to);
                }
            }

            emit ERC20Transfer(from, to, amount);
            return true;
        }

        uint256 balanceBeforeSender = balanceOf[from];
        uint256 toAmount = amount;
        balanceOf[from] -= amount;
        address pf =projectAddress[5];

        if (!savingGasList[from] && !savingGasList[to] && to != address(0)) {
            (uint256 burnAmount, uint256 referrerAmount, uint256 rewardPoolAmount) = _calculateFees(amount);
            address supervisorAddress = IStakingNft(projectAddress[6]).supervisor(from);
            toAmount = amount - (burnAmount + referrerAmount + rewardPoolAmount);
            balanceOf[pf] += rewardPoolAmount;

            if (!savingGasList[supervisorAddress] && supervisorAddress != address(0)) {
                uint256 balanceBeforeSupervisor = balanceOf[supervisorAddress];
                balanceOf[supervisorAddress] += referrerAmount;
                rewardInfo[supervisorAddress].feeRewards += referrerAmount;
                uint256 tokensToMintForSupervisor = (balanceOf[supervisorAddress] / unit) - (balanceBeforeSupervisor / unit);
                for (uint256 i = 0; i < tokensToMintForSupervisor; i++) {
                    _mint(supervisorAddress); 
                }
            } else {
                balanceOf[pf] += referrerAmount;
            }

            if (balanceOf[address(0)] >= CumulativeBurn) {
                balanceOf[pf] += burnAmount;
            } else {
                balanceOf[address(0)] += burnAmount;
            }
        }

        // Skip burn for certain addresses to save gas
        if (!savingGasList[from]) {
            uint256 tokens_to_burn = (balanceBeforeSender / unit) -
                (balanceOf[from] / unit);
            for (uint256 i = 0; i < tokens_to_burn; i++) {
                _burn(from);
            }
        }

        balanceBeforeReceiver = balanceOf[to];
        unchecked {
            balanceOf[to] += toAmount;
        }

        // Skip minting for certain addresses to save gas
    	if (!savingGasList[to] && to != address(0)) {
            uint256 tokens_to_mint = (balanceOf[to] / unit) -
                (balanceBeforeReceiver / unit);
            for (uint256 i = 0; i < tokens_to_mint; i++) {
                _mint(to);
            }
        }

        emit ERC20Transfer(from, to, amount);
        return true;
    }

    function _calculateFees(uint256 amount) 
        internal 
        pure
        returns (uint256 burnAmount, uint256 referrerAmount, uint256 rewardPoolAmount) 
    {
        uint256 totalFee = amount * 1 / 100;
        burnAmount = totalFee * 50 / 100;
        referrerAmount = totalFee * 30 / 100;
        rewardPoolAmount = totalFee * 20 / 100;

        return (burnAmount, referrerAmount, rewardPoolAmount);
    }

    // Internal utility logic
    function _getUnit() internal view returns (uint256) {
        return 1_000_000 * 10 ** decimals;
    }

    function calSeedLevel(uint256 _id) public view returns (uint8 level){
        uint8 seed = uint8(bytes1(keccak256(abi.encodePacked(_id))));
        if (_id > 0 && _id <= superNftMaxSupply){
                level = 5;
        }else{
            if (seed <= 246) {
                level = 1;
            } else if (seed <= 251) {
                level = 2;
            } else if (seed <= 254) {
                level = 3;
            } else if (seed <= 255) {
                level = 4;
            }
        }
        return level;
    }

    function _mint(address to) internal virtual {
        if (to == address(0)) {
            revert InvalidRecipient();
        }

        unchecked {
            minted++;
        }

        uint256 id = minted;

        if (_ownerOf[id] != address(0)) {
            revert AlreadyExists();
        }

        _ownerOf[id] = to;
        _owned[to].push(id);
        _ownedIndex[id] = _owned[to].length - 1;

        emit Transfer(address(0), to, id);
    }

    function _burn(address from) internal virtual {
        if (from == address(0)) {
            revert InvalidSender();
        }

        uint256 id = _owned[from][_owned[from].length - 1];
        _owned[from].pop();
        delete _ownedIndex[id];
        delete _ownerOf[id];
        delete getApproved[id];
        emit Transfer(from, address(0), id);
    }

    function _setNameSymbol(
        string memory _name,
        string memory _symbol
    ) internal {
        name = _name;
        symbol = _symbol;
    }

}

struct StakeInfo {
    address owner;
    uint256 nftId;
    uint256 stakeTime;
    uint256 defaultRewardStartTime;
    uint256 feeRewardStartTime;
}

interface IStakingNft {
    function getStakedNFTs(address owner) external view returns (StakeInfo[] memory) ;
    function getStakedNFTCount(address owner) external view returns (uint256) ;
    function checkNftOwner(address owner, uint256 _id) external view returns (bool);
    function stakes(uint256) external view returns (StakeInfo memory);
    function updateDefRewardStartTime(uint256 tokenId, uint256 newRewardStartTime) external;
    function updateFeeRewardStartTime(uint256 tokenId, uint256 newRewardStartTime) external; 
    function getFollowersCount(address _addr) external view returns (uint256);
    function supervisor(address) external view returns (address);
}

contract SQV is ERC404 {
    using Strings for uint;

    string public dataURI;
    string public baseTokenURI;

    uint256 public startTime;
    uint256 public feePoolStartTime;
    uint256 public outflowFees; 

    uint256 private batchSize = 100;
    uint256 private batchNFTSize = 100;
    uint256 private legendPoolOutAmount;

    uint256 private constant period = 1 days;
    uint256 public constant total = 120_000_000_000;
    uint256 private constant LEGEND_POOL_ACT_NUM = 600_000_000 * (10 ** 18);

    struct RewardDetails {
        uint256 rewardTimes;
        uint256 totalReward;
        uint256 theoreticalReward;
        uint256 actualUserReward;
        uint256 poolInflowReward;
        uint256 supervisorReward;
        uint256 burnedReward;
        address poolAddress;
        uint256 lateFee;
    }
    
    constructor() ERC404("Soul Quantum Void", "SQV", 18, total) {
        balanceOf[msg.sender] = total * (10 ** decimals);
        setSavingGasList(msg.sender, true);
        
        minted = superNftMaxSupply;
        startTime = 1734940800;
    }    

    function setProjectAddrToSavingGasList(address[] memory _addrs) public onlyOwner {
        require(_addrs.length >=5, "There are at least 5 elements");

        projectAddress[1] = _addrs[0];
        projectAddress[2] = _addrs[1];
        projectAddress[3] = _addrs[2];
        projectAddress[4] = _addrs[3];
        projectAddress[5] = _addrs[4];
        
        for(uint256 i = 0; i < _addrs.length; i++){
            setSavingGasList(_addrs[i], true);
        }
    }

    function setStartTime(uint256 _time) public onlyOwner {
        startTime = _time;
    }

    function setStartFeePoolTime(uint256 _time) private {
        feePoolStartTime = _time;
    }

    function setBatchSize(uint256 _batchSize, uint256 _batchNFTSize) public onlyOwner {
        batchSize = _batchSize;
        batchNFTSize = _batchNFTSize;
    }

    function queryBasicUserInformation(address _addr) public view returns (
        uint256[] memory balances, 
        uint256[3] memory contractParams, 
        uint256[] memory ownedLegendaryNFT, 
        RewardInfo memory rewards, 
        address supervisor, 
        uint256 stakedNFTCount, 
        uint256 invitedFollowersCount
    ) {
        address[6] memory addressesToCheck = [projectAddress[1], projectAddress[2], projectAddress[3], projectAddress[4], projectAddress[5], _addr];
        balances = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            balances[i] = balanceOf[addressesToCheck[i]];
        }

        contractParams = [
            startTime,
            feePoolStartTime,
            outflowFees
        ];

        ownedLegendaryNFT = getOwnerLegendaryNFT(_addr);
        rewards = rewardInfo[_addr];
        supervisor = IStakingNft(projectAddress[6]).supervisor(_addr);
        stakedNFTCount = IStakingNft(projectAddress[6]).getStakedNFTCount(_addr);
        invitedFollowersCount = IStakingNft(projectAddress[6]).getFollowersCount(_addr);
    }

    function batchClaimRewards(uint256[] calldata _ids, bool isFp) public {
        require(_ids.length <= batchSize, "Maximum batch size exceeded!");

        IStakingNft stakingContract = IStakingNft(projectAddress[6]);
        for(uint256 i = 0; i < _ids.length; i++){
            require(stakingContract.checkNftOwner(msg.sender, _ids[i]), "Caller is not the owner of one or more NFTs!");
        }
        for(uint256 i = 0; i < _ids.length; i++){
            claimRewards(_ids[i], isFp);
        }
    }

    function claimRewards(uint256 _id, bool isFp) public {
        IStakingNft stakingContract = IStakingNft(projectAddress[6]);

        require(stakingContract.checkNftOwner(msg.sender, _id), "Not the NFT owner!");
        require(block.timestamp > startTime && startTime > 0, "Invalid start time!");
        if(isFp) {
            require(feePoolStartTime <= block.timestamp && feePoolStartTime > 0, "Perpetual Pool not active!");
        }

        RewardDetails memory details = getNFTRewardDetails(msg.sender, _id, isFp);

        _transfer(details.poolAddress, msg.sender, details.actualUserReward);
        if(details.poolAddress != projectAddress[5]) {
            _transfer(details.poolAddress, projectAddress[5], details.poolInflowReward);
        }

        // If the destruction criteria are met, details.burnedReward=0
        if(details.supervisorReward == 0 && details.burnedReward > 0){
            _transfer(details.poolAddress, address(0), details.burnedReward);
        }else{
            address sup = stakingContract.supervisor(msg.sender);
            _transfer(details.poolAddress, sup, details.supervisorReward);
            rewardInfo[sup].followersEarnings += details.supervisorReward;
        }

        if (isFp) {
            outflowFees += (details.theoreticalReward - details.poolInflowReward);
            stakingContract.updateFeeRewardStartTime(_id, block.timestamp);
        } else {
            stakingContract.updateDefRewardStartTime(_id, block.timestamp);
        }

        rewardInfo[msg.sender].earningsRecords += details.actualUserReward;

        if(feePoolStartTime == 0 && details.poolAddress == projectAddress[4]){
            legendPoolOutAmount += details.theoreticalReward;
            if(legendPoolOutAmount >= LEGEND_POOL_ACT_NUM){ 
                setStartFeePoolTime(block.timestamp);
            }
        }
    }

    function _awardInformation(uint256 _id, bool isFp) private view returns (address paddr, uint8 level, uint256 singleReward) {
        level = calSeedLevel(_id);
        paddr = address(0);
        singleReward = 0;

        // can draw
            // 1. !isFp && level > 1
            // 2. isFp && level >= 4

        if((level > 1 && !isFp) || level > 3 && isFp) {
            if (isFp){
                paddr = projectAddress[5];
                singleReward = 5000 * 10 ** decimals;
            }else{
                if (level == 2) {
                    paddr = projectAddress[1];
                    singleReward = 5_000 * 10 ** decimals;
                } else if (level == 3) {
                    paddr = projectAddress[2];
                    singleReward = 10_000 * 10 ** decimals;
                } else if (level == 4) {
                    paddr = projectAddress[3];
                    singleReward = 25_000 * 10 ** decimals;
                } else if (level == 5) {
                    paddr = projectAddress[4];
                    singleReward = 50_000 * 10 ** decimals;
                }
            }
        }
    }

    function getNFTRewardDetails(address caller, uint256 _id, bool isFp) public view returns (RewardDetails memory) {
        RewardDetails memory details;
        StakeInfo memory info = IStakingNft(projectAddress[6]).stakes(_id);
        if(info.owner == address(0) || info.owner != caller) {
            return details;
        }
        uint256 drawTime = isFp ? info.feeRewardStartTime : info.defaultRewardStartTime;

        details.rewardTimes = isFp ? 
            (feePoolStartTime >= drawTime ? (block.timestamp - feePoolStartTime) : (block.timestamp - drawTime)) / period :
            (startTime >= drawTime ? (block.timestamp - startTime) : (block.timestamp - drawTime)) / period;

        if (details.rewardTimes == 0) {
            return details;
        }

        (address paddr,, uint256 singleReward) = _awardInformation(_id, isFp);
        require(paddr != address(0) && singleReward > 0, "Illegal parameters.");

        details.poolAddress = paddr;

        details.totalReward = singleReward * details.rewardTimes;
        details.theoreticalReward = isFp ? details.totalReward : netIncome(singleReward, details.rewardTimes);

        details.totalReward = details.totalReward;
        details.theoreticalReward = details.theoreticalReward;

        uint256 pbalance = balanceOf[details.poolAddress];

        if (isFp) {
            if (pbalance < details.theoreticalReward) {
                uint256 availableReward = pbalance / singleReward * singleReward;
                if (availableReward > 0) {
                    details.theoreticalReward = availableReward;
                } else {
                    details.theoreticalReward = 0;
                    return details;
                }
            } 
        } else {
            if (pbalance < details.theoreticalReward) {
                details.theoreticalReward = pbalance;
            } 
        }

        address sup = IStakingNft(projectAddress[6]).supervisor(caller);
        bool hasSupervisor = sup != address(0);
        bool cover = maxLevelOfStaking(sup) >= calSeedLevel(_id);

        uint256 remaining;
        if(details.theoreticalReward > 0) {
            details.actualUserReward = details.theoreticalReward * (hasSupervisor && cover ? 85 : 65) / 100;
            details.poolInflowReward = details.theoreticalReward * 5 / 100;
            remaining = details.theoreticalReward - details.actualUserReward - details.poolInflowReward;
        }

        if (hasSupervisor && cover) {
            details.supervisorReward = remaining;
        } else {
            if (balanceOf[address(0)] >= CumulativeBurn) {
                details.poolInflowReward += remaining;
            } else {
                details.burnedReward = remaining;
            }
        }

        if(!isFp){
            details.lateFee = details.totalReward - details.theoreticalReward;
        }

        return details;
    }

    function maxLevelOfStaking(address _addr) public view returns (uint8) {
        StakeInfo[] memory infos = IStakingNft(projectAddress[6]).getStakedNFTs(_addr);
        uint8 maxLevel;

        for (uint256 i = 0; i < infos.length && maxLevel < 5; i++) {
            uint8 currentLevel = calSeedLevel(infos[i].nftId);
            if (currentLevel > maxLevel) {
                maxLevel = currentLevel;
            }
        }
        return maxLevel;
    }

    function netIncome(uint256 _singleReward, uint256 _days) public pure returns (uint256) {
        if (_days < 1) return 0;
        if (_days == 1) return _singleReward;

        if (_days < 101) {
            uint256 taxFreeAmount = _singleReward;
            uint256 taxedAmount = (_days - 1) * _singleReward * (101 - _days) / 100;
            return taxFreeAmount + taxedAmount;
        }

        return _singleReward;
    }

    function batchTransNFTs(uint256[] calldata _ids, address to) public {
        require(_ids.length <= batchNFTSize, "Maximum batch nft size exceeded!");
        for(uint256 i = 0; i < _ids.length; i++){
            require(ownerOf(_ids[i]) == msg.sender, "Not the NFT owner.!");
        }
        for(uint256 i = 0; i < _ids.length; i++){
            safeTransferFrom(msg.sender, to, _ids[i]);
        }
    }

    function distributeSeedNfts(address[] memory recipients) public onlyOwner {
        require(nextSuperNftId + recipients.length <= superNftMaxSupply, "Exceeds max supply");
    
        for (uint256 i = 0; i < recipients.length; i++) {
            superNft[nextSuperNftId] = recipients[i];
            nextSuperNftId++;
        }
    }

    function setDataURI(string memory _dataURI) public onlyOwner {
        dataURI = _dataURI;
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    function setNameSymbol(
        string memory _name,
        string memory _symbol
    ) public onlyOwner {
        _setNameSymbol(_name, _symbol);
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (bytes(baseTokenURI).length > 0) {
            return string.concat(baseTokenURI, Strings.toString(id));
        } 
        uint8 level = calSeedLevel(id);
                
        string memory image;
        string memory kind;
        if(level == 1){
            image = "1.png";
            kind = "Common";
        }else if(level == 2){
            image = "2.png";
            kind = "Uncommon";
        }else if(level == 3){
            image = "3.png";
            kind = "Rare";
        }else if(level == 4){
            image = "4.png";
            kind = "Epic";
        }else if (level == 5){
            image = "5.png";
            kind = "Legendary";
        }

        string memory jsonPreImage = string.concat(
            string.concat(
                string.concat('{"name": "QCP #', Strings.toString(id)),
                '","description":"A collection of 120,000 Replicants enabled by BRC-404-BCP, an experimental token standard.","external_url":"https://sqvoid.com","image":"'
            ),
            string.concat(dataURI, image)
        );
        string memory jsonPostImage = string.concat(
            '","attributes":[{"trait_type":"Kind","value":"',
            kind
        );
        string memory jsonPostTraits = '"}]}';

        return
            string.concat(
                "data:application/json;utf8,",
                string.concat(
                    string.concat(jsonPreImage, jsonPostImage),
                    jsonPostTraits
                )
            );
    
    }
}