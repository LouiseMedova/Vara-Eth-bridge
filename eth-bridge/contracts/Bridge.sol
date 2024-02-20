// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import './Token.sol';

contract Bridge is AccessControl, ReentrancyGuard{

    bytes32 public constant ADMIN = keccak256("ADMIN");

    address public addressOfToken;
    address public admin;

    uint256 threshold;
    uint256 nonceIdVaraToEth;
    uint256 nonceIdEthToVara;
    
    // mapping from nonceIdVaraToEth to Transit struct
    mapping(uint256 => Transit) public transitsVaraToEth;

    // mapping from nonceIdEthToVara to Transit struct
    mapping(uint256 => Transit) public transitsEthToVara;

    struct Transit {
        address sender;
        address recipient;
        uint256 amount;
        uint256 nonceId;
    }

    constructor(address _addressOfToken, uint256 _threshold) {
        addressOfToken = _addressOfToken;
        threshold = _threshold;
        _grantRole(ADMIN, msg.sender);
        admin = msg.sender;
        nonceIdVaraToEth = 0;
    }

    event TeleportEthToVara (
        address sender,
        address recipient,
        uint amount,
        uint nonceId
    );

    event TeleportVaraToEth (
        address[] sender,
        address[] recipient,
        uint[] amount,
        uint[] nonceId
    );

    /// @dev Updates the address of token contract
    /// @param _addressOfToken New address of token contract
    function updateTokenAddress(address _addressOfToken) onlyRole(ADMIN) public {
        addressOfToken = _addressOfToken;
    }

    /// @dev Burns the user's tokens and emits an {InitSwap} event indicating the transit from Ethereum to Vara
    /// @param _recipient The address of the user receiving tokens on the Vara
    /// @param _amount The amount of tokens to be transferred to Vara
    function transitEthToVara(
        address _recipient, 
        uint _amount
        ) external {
            address sender = msg.sender;
           
            require(_amount >= threshold, "Too low amount");
            uint256 nonceId = nonceIdVaraToEth;
            transitsVaraToEth[nonceId] = 
                Transit({
                    sender: sender, 
                    recipient: _recipient, 
                    amount: _amount, 
                    nonceId: nonceId
                    });
            nonceIdVaraToEth++;
            Token(addressOfToken).burn(sender, _amount);
            emit TeleportEthToVara(
                sender,
                _recipient,
                _amount,
                nonceId
            );
    }


    function transitVaraToEthBatch( 
        address[] calldata _senders,
        address[] calldata _recipients, 
        uint[] calldata _amounts, 
        uint[] calldata _nonces
        ) nonReentrant
          external {
            require(msg.sender == admin, "Not admin");
            uint len = _senders.length;
            require(len == _recipients.length, "Wrong length of arrays");
            require(len == _amounts.length, "Wrong length of arrays");
            require(len == _nonces.length, "Wrong length of arrays");
            uint newNonceIdVaraToEth = nonceIdEthToVara + len;
            for (uint i=0; i < len; i++) {
                require(_nonces[i] >= nonceIdEthToVara && _nonces[i] < newNonceIdVaraToEth, "Wrong nonce");
                transitVaraToEth(_senders[i], _recipients[i], _amounts[i], _nonces[i]);
            }
            nonceIdEthToVara = newNonceIdVaraToEth;
            emit TeleportVaraToEth(
                _senders,
                _recipients,
                _amounts,
                _nonces
            );
          }

    /// @dev Сalculates the hash from the input parameters and using `_signature` recovers sender address
    /// @dev If recovered address coincides with `_sender` and the function is called for the first time, it mints the tokens to the recipient
    /// @dev Emits an {Redeem} event indicating the token redemption
    /// @param _sender The address of the user having sended tokens from `_chainFrom`
    /// @param _recipient The address of the user receiving tokens on `_chainTo`
    /// @param _amount The amount of tokens to be swaped
    /// @param _nonceId The transaction identifier
    function transitVaraToEth( 
        address _sender,
        address _recipient, 
        uint _amount, 
        uint _nonceId 
        )  internal {
            Transit memory transit = transitsVaraToEth[_nonceId];
            require(transit.sender == address(0), "The transit with this nonceId already exists");
            require(transit.recipient == address(0), "The transit with this nonceId already exists");
            transitsVaraToEth[_nonceId] = Transit({
                    sender: _sender, 
                    recipient: _recipient, 
                    amount: _amount, 
                    nonceId: _nonceId
                    });
            Token(addressOfToken).mint(_recipient, _amount);

          }

    function getLastNonceEthToVara() public view returns (uint256) {
        return nonceIdVaraToEth;
    }

    function getQueue(uint256 _nonceIdVaraToEth) public view returns (Transit[] memory) {
        require(_nonceIdVaraToEth < nonceIdVaraToEth, "Wrong nonce");
        Transit[] memory transits = new Transit[](nonceIdVaraToEth - _nonceIdVaraToEth);

        for (uint i=_nonceIdVaraToEth; i < nonceIdVaraToEth; i++) {
            transits[i] = transitsVaraToEth[i];
        }
        return transits;
    }

    // function clearQueue(uint256 _nonceIdVaraToEth)

}
