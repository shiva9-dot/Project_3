pragma solidity ^0.5.0;

contract LifeAssureCoin {
    address public owner;

    enum PolicyType { Basic, Comprehensive, EnhancedPlus }

    struct Policy {
        uint256 coverageAmount;
        uint256 premiumAmount;
        uint256 durationMonths;
        uint256 nextPaymentDue;
        address beneficiary;
        bool deathCertificateSubmitted;
        PolicyType policyType;
    }

    struct CustomerInfo {
        string name;
        uint256 birthYear;
        string addressInfo;
        bool doesSmoke;
        bool hasHeartDisease;
        bool hasDiabetes;
        bool hasRespiratoryIssue;
    }

    mapping(address => Policy) public policies;
    mapping(address => CustomerInfo) public customerInfo;
    mapping(address => uint256) public balances;

    event PolicyIssued(
        address indexed policyholder,
        PolicyType policyType,
        uint256 coverageAmount,
        uint256 premiumAmount,
        uint256 durationMonths,
        address beneficiary
    );
    event PremiumPaid(address indexed policyholder, uint256 amount);
    event ClaimInitiated(address indexed policyholder, uint256 amount);
    event CustomerInfoSubmitted(
        address indexed policyholder,
        string name,
        uint256 birthYear,
        string addressInfo,
        bool doesSmoke,
        bool hasHeartDisease,
        bool hasDiabetes,
        bool hasRespiratoryIssue
    );
    event CoverageUpdated(address indexed policyholder, uint256 newCoverageAmount, uint256 newPremiumAmount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function.");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function submitCustomerInfo(
        string memory _name,
        uint256 _birthYear,
        string memory _addressInfo,
        bool _doesSmoke,
        bool _hasHeartDisease,
        bool _hasDiabetes,
        bool _hasRespiratoryIssue
    ) public {
        customerInfo[msg.sender] = CustomerInfo({
            name: _name,
            birthYear: _birthYear,
            addressInfo: _addressInfo,
            doesSmoke: _doesSmoke,
            hasHeartDisease: _hasHeartDisease,
            hasDiabetes: _hasDiabetes,
            hasRespiratoryIssue: _hasRespiratoryIssue
        });

        emit CustomerInfoSubmitted(msg.sender, _name, _birthYear, _addressInfo, _doesSmoke, _hasHeartDisease, _hasDiabetes, _hasRespiratoryIssue);
    }

    function issuePolicy(
        address _policyholder,
        PolicyType _policyType,
        address _beneficiary
    ) public onlyOwner {
        require(policies[_policyholder].coverageAmount == 0, "Policy already exists for the policyholder.");
        CustomerInfo storage info = customerInfo[_policyholder];
        require(info.birthYear != 0, "Customer information must be submitted first.");

        uint256 age = calculateAge(info.birthYear);
        uint256 coverageDurationMonths = (65 > age) ? (65 - age) * 12 : 0;

        uint256 coverageAmount = getCoverageAmount(_policyType);
        uint256 basePremium = getBasePremium(_policyType);
        uint256 premiumAmount = calculatePremium(age, info.doesSmoke, info.hasHeartDisease, info.hasDiabetes, info.hasRespiratoryIssue, basePremium, coverageAmount);

        policies[_policyholder] = Policy({
            coverageAmount: coverageAmount,
            premiumAmount: premiumAmount,
            durationMonths: coverageDurationMonths,
            nextPaymentDue: now + 30 days,
            beneficiary: _beneficiary,
            deathCertificateSubmitted: false,
            policyType: _policyType
        });

        emit PolicyIssued(_policyholder, _policyType, coverageAmount, premiumAmount, coverageDurationMonths, _beneficiary);
    }

    function calculateAge(uint256 birthYear) private view returns (uint256) {
        uint256 currentYear = block.timestamp / 31536000 + 1970; // Approximation of the current year
        return currentYear - birthYear;
    }

    function getBasePremium(PolicyType policyType) private pure returns (uint256) {
        if (policyType == PolicyType.Basic) return 0.00150 ether;
        else if (policyType == PolicyType.Comprehensive) return 0.00200 ether;
        else if (policyType == PolicyType.EnhancedPlus) return 0.00450 ether;
    }

    function getCoverageAmount(PolicyType policyType) private pure returns (uint256) {
        if (policyType == PolicyType.Basic) return 100 ether;
        else if (policyType == PolicyType.Comprehensive) return 200 ether;
        else if (policyType == PolicyType.EnhancedPlus) return 500 ether;
    }

    function calculatePremium(
        uint256 age,
        bool doesSmoke,
        bool hasHeartDisease,
        bool hasDiabetes,
        bool hasRespiratoryIssue,
        uint256 basePremium,
        uint256 coverageAmount
    ) private pure returns (uint256) {
        uint256 premium = basePremium;

        // Adjust premium based on age
        if (age <= 30) {
            premium = premium * 90 / 100; // 10% discount for under 30
        } else {
            // Incrementally increase the premium by 5% for each decade above 30
            premium += (age - 30) / 10 * premium * 5 / 100;
        }

        // Health risk adjustments
        if (doesSmoke) premium += premium * 20 / 100;
        if (hasHeartDisease || hasDiabetes || hasRespiratoryIssue) premium += premium * 15 / 100;

        // Adjust premium based on coverage amount
        premium += (coverageAmount - 100 ether) * premium / 100 ether; // Increase premium by 1% for every 100 ether increase in coverage amount

        return premium;
    }

    function payPremium() public payable {
        Policy storage policy = policies[msg.sender];
        require(policy.coverageAmount > 0, "No active policy found for the policyholder.");
        require(now >= policy.nextPaymentDue, "Premium payment not yet due.");
        require(msg.value >= policy.premiumAmount, "Insufficient amount to pay premium.");

        balances[msg.sender] += msg.value;
        policy.nextPaymentDue += 30 days;

        emit PremiumPaid(msg.sender, msg.value);
    }

    function initiateClaim(address beneficiary, bool deathCertificateProvided) public {
        Policy storage policy = policies[msg.sender];
        require(policy.coverageAmount > 0, "No active policy found for the policyholder.");
        require(beneficiary == policy.beneficiary, "Beneficiary address does not match.");
        require(deathCertificateProvided, "Death certificate must be provided to initiate a claim.");

        address payable policyholder = address(uint160(msg.sender));
        policyholder.transfer(policy.coverageAmount);

        emit ClaimInitiated(msg.sender, policy.coverageAmount);
        delete policies[msg.sender];
    }

    function changeCoverageAmount(address _policyholder, uint256 _newCoverageAmount) public onlyOwner {
        Policy storage policy = policies[_policyholder];
        require(_newCoverageAmount > policy.coverageAmount, "New coverage amount must be higher than current coverage amount.");

        // Update coverage amount
        policy.coverageAmount = _newCoverageAmount;

        CustomerInfo storage info = customerInfo[_policyholder];
        uint256 age = calculateAge(info.birthYear);

        // Recalculate premium based on updated information
        uint256 newPremiumAmount = calculatePremium(age, info.doesSmoke, info.hasHeartDisease, info.hasDiabetes, info.hasRespiratoryIssue, getBasePremium(policy.policyType), _newCoverageAmount);

        // Update premium amount
        policy.premiumAmount = newPremiumAmount;

        emit CoverageUpdated(_policyholder, _newCoverageAmount, newPremiumAmount);
    }
}
