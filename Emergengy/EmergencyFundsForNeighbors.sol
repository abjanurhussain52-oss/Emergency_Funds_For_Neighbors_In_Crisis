// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title NeighborhoodEmergencyFund
 * @dev A decentralized emergency fund for community mutual aid
 */
contract NeighborhoodEmergencyFund {
    
    struct EmergencyRequest {
        address requester;
        uint256 amount;
        string description;
        uint256 timestamp;
        bool fulfilled;
        uint256 votes;
        mapping(address => bool) hasVoted;
    }
    
    mapping(uint256 => EmergencyRequest) public emergencyRequests;
    mapping(address => uint256) public contributions;
    mapping(address => bool) public isVerifiedNeighbor;
    
    uint256 public totalFund;
    uint256 public requestCounter;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTES_REQUIRED = 3;
    
    address public admin;
    
    event ContributionMade(address indexed contributor, uint256 amount);
    event EmergencyRequested(uint256 indexed requestId, address indexed requester, uint256 amount);
    event RequestApproved(uint256 indexed requestId, uint256 amount);
    event NeighborVerified(address indexed neighbor);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyVerifiedNeighbor() {
        require(isVerifiedNeighbor[msg.sender], "Only verified neighbors can perform this action");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        isVerifiedNeighbor[msg.sender] = true;
    }
    
    /**
     * @dev Contribute funds to the emergency pool
     */
    function contributeFunds() external payable {
        require(msg.value > 0, "Contribution must be greater than 0");
        
        contributions[msg.sender] += msg.value;
        totalFund += msg.value;
        
        emit ContributionMade(msg.sender, msg.value);
    }
    
    /**
     * @dev Submit an emergency funding request
     * @param _amount Amount of ETH requested (in wei)
     * @param _description Description of the emergency situation
     */
    function requestEmergencyFund(uint256 _amount, string memory _description) external onlyVerifiedNeighbor {
        require(_amount > 0, "Request amount must be greater than 0");
        require(_amount <= totalFund, "Insufficient funds in the pool");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        requestCounter++;
        EmergencyRequest storage newRequest = emergencyRequests[requestCounter];
        newRequest.requester = msg.sender;
        newRequest.amount = _amount;
        newRequest.description = _description;
        newRequest.timestamp = block.timestamp;
        newRequest.fulfilled = false;
        newRequest.votes = 0;
        
        emit EmergencyRequested(requestCounter, msg.sender, _amount);
    }
    
    /**
     * @dev Vote on an emergency request
     * @param _requestId ID of the emergency request to vote on
     */
    function voteOnRequest(uint256 _requestId) external onlyVerifiedNeighbor {
        require(_requestId > 0 && _requestId <= requestCounter, "Invalid request ID");
        
        EmergencyRequest storage request = emergencyRequests[_requestId];
        require(!request.fulfilled, "Request already fulfilled");
        require(block.timestamp <= request.timestamp + VOTING_PERIOD, "Voting period has ended");
        require(!request.hasVoted[msg.sender], "You have already voted on this request");
        require(request.requester != msg.sender, "Cannot vote on your own request");
        
        request.hasVoted[msg.sender] = true;
        request.votes++;
        
        // Automatically approve and transfer funds if minimum votes reached
        if (request.votes >= MIN_VOTES_REQUIRED) {
            _approveFunding(_requestId);
        }
    }
    
    /**
     * @dev Verify a new neighbor (admin only)
     * @param _neighbor Address of the neighbor to verify
     */
    function verifyNeighbor(address _neighbor) external onlyAdmin {
        require(_neighbor != address(0), "Invalid address");
        require(!isVerifiedNeighbor[_neighbor], "Neighbor already verified");
        
        isVerifiedNeighbor[_neighbor] = true;
        emit NeighborVerified(_neighbor);
    }
    
    /**
     * @dev Internal function to approve funding and transfer ETH
     * @param _requestId ID of the request to approve
     */
    function _approveFunding(uint256 _requestId) internal {
        EmergencyRequest storage request = emergencyRequests[_requestId];
        require(!request.fulfilled, "Request already fulfilled");
        require(address(this).balance >= request.amount, "Insufficient contract balance");
        
        request.fulfilled = true;
        totalFund -= request.amount;
        
        (bool success, ) = payable(request.requester).call{value: request.amount}("");
        require(success, "Transfer failed");
        
        emit RequestApproved(_requestId, request.amount);
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Get details of an emergency request
     * @param _requestId ID of the request
     */
    function getRequestDetails(uint256 _requestId) external view returns (
        address requester,
        uint256 amount,
        string memory description,
        uint256 timestamp,
        bool fulfilled,
        uint256 votes
    ) {
        require(_requestId > 0 && _requestId <= requestCounter, "Invalid request ID");
        
        EmergencyRequest storage request = emergencyRequests[_requestId];
        return (
            request.requester,
            request.amount,
            request.description,
            request.timestamp,
            request.fulfilled,
            request.votes
        );
    }
}
