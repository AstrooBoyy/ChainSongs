pragma solidity ^0.5.0;

contract SongsContract {
    struct Owner {
        address owner;
        uint16 royaltyPoints;
        uint16 royaltyPointsOffered;
        uint256 pricePerRoyaltyPoint;
    }

    struct Song {
        bool wasReleased;
        uint256 balance;
        address creator;
        uint256 ownersSize;
        mapping(address => Owner) owners;
        mapping(address => bool) authorizedListeners;
    }

    uint256 public constant songPrice = 8000000000000000;
    uint16 public constant MAX_ROYALTY_POINTS = 10000;

    mapping(address => Song) public songs;
    mapping(address => uint256) public royaltiesPayable;

    function registerSong(address songAddress) public returns (bool success) {
        require(
            !isSongRegistered(songAddress),
            "The song is already registered"
        );
        Owner memory currentOwner = Owner(msg.sender, MAX_ROYALTY_POINTS, 0, 0);

        Song memory currentSong = Song(false, 0, msg.sender, 0);
        songs[songAddress] = currentSong;
        songs[songAddress].ownersSize += 1;
        songs[songAddress].owners[msg.sender] = currentOwner;
        songs[songAddress].wasReleased = false;
        songs[songAddress].creator = msg.sender;

        return true;
    }

    function registerOwner(address songAddress, address newOwner)
        internal
        returns (bool)
    {
        require(isSongRegistered(songAddress), "The song is not registered");

        if (!isOwner(songAddress, newOwner)) {
            Owner memory newestOwner;
            newestOwner.owner = newOwner;
            songs[songAddress].ownersSize += 1;
            songs[songAddress].owners[newOwner] = newestOwner;
        }
        return true;
    }

    function preregisterOwner(
        address songAddress,
        address newOwner,
        uint16 royalties
    ) external returns (bool success) {
        require(isSongRegistered(songAddress), "The song is not registered");
        require(
            isCreator(songAddress, msg.sender),
            "The caller is not the creator of the song"
        );
        require(
            songs[songAddress].wasReleased == false,
            "The preregistration can't happen after royalties started being sold to the public"
        );
        require(
            royalties <= viewMaxRoyaltyPoints(),
            "You can't transfer more royalties than the existing ones"
        );
        uint16 ownedRoyalties = viewOwnRoyaltyPoints(songAddress, msg.sender);
        require(
            royalties <= ownedRoyalties,
            "You can't transfer more royalties than the ones you own"
        );
        require(
            royalties > 0,
            "You have to transfer at least one royalty point"
        );

        registerOwner(songAddress, newOwner);
        assert(isOwner(songAddress, newOwner));

        songs[songAddress].owners[msg.sender].royaltyPoints -= royalties;
        songs[songAddress].owners[newOwner].royaltyPoints = royalties;

        return true;
    }

    function buy(address payable songAddress)
        public
        payable
        returns (bool success)
    {
        require(isSongRegistered(songAddress), "The song is not registered");
        require(msg.value == songPrice);
        songs[songAddress].balance += msg.value;
        songs[songAddress].authorizedListeners[msg.sender] = true;
        return true;
    }

    function sellRoyalties(
        address songAddress,
        uint16 royalties,
        uint256 newPricePerRoyaltyPoint
    ) public returns (bool success) {
        require(
            isOwner(songAddress, msg.sender),
            "This is not an owner of the song"
        );
        require(
            royalties <= viewMaxRoyaltyPoints(),
            "You can't sell more royalties than the existing ones"
        );
        uint16 ownedRoyalties = viewOwnRoyaltyPoints(songAddress, msg.sender);
        require(
            royalties <= ownedRoyalties,
            "You can't sell more royalties than what you own"
        );
        require(royalties > 0, "You have to sell at least one royalty point");

        songs[songAddress].wasReleased = true;
        songs[songAddress].owners[msg.sender].royaltyPointsOffered += royalties;
        songs[songAddress]
            .owners[msg.sender]
            .pricePerRoyaltyPoint = newPricePerRoyaltyPoint;

        return true;
    }

    function withdrawOffer(address songAddress, uint16 royalties)
        public
        returns (bool success)
    {
        require(
            isOwner(songAddress, msg.sender),
            "This is not an owner of the song"
        );
        require(
            royalties <= viewMaxRoyaltyPoints(),
            "You can't withdraw more royalties than the existing ones"
        );
        uint16 ownedRoyalties = viewOwnRoyaltyPoints(songAddress, msg.sender);
        require(
            royalties <= ownedRoyalties,
            "You can't withdraw more royalties than what you own"
        );
        require(
            songs[songAddress].owners[msg.sender].royaltyPointsOffered +
                royalties <=
                ownedRoyalties,
            "You can't withdraw more royalties than what you offered"
        );

        songs[songAddress].owners[msg.sender].royaltyPointsOffered -= royalties;

        return true;
    }

    function buyRoyalties(address songAddress, address seller)
        public
        payable
        returns (bool success)
    {
        require(
            isOwner(songAddress, seller),
            "That seller is not an owner of the song"
        );
        uint256 royaltiesPrice = viewRoyaltyOfferedPrice(songAddress, seller);
        require(
            msg.value == royaltiesPrice,
            "The money sent doesn't match the price"
        );

        royaltiesPayable[seller] += msg.value;

        registerOwner(songAddress, msg.sender);
        assert(isOwner(songAddress, msg.sender));

        uint16 royaltiesOffered = songs[songAddress]
            .owners[seller]
            .royaltyPointsOffered;
        songs[songAddress].owners[msg.sender].royaltyPoints += royaltiesOffered;
        songs[songAddress].owners[seller].royaltyPoints -= royaltiesOffered;
        songs[songAddress].owners[seller].royaltyPointsOffered = 0;
        songs[songAddress].owners[seller].pricePerRoyaltyPoint = 0;

        return true;
    }

    function viewSongPrice() public pure returns (uint256) {
        return (songPrice);
    }

    function viewMaxRoyaltyPoints() public pure returns (uint16) {
        return (MAX_ROYALTY_POINTS);
    }

    function viewOwnRoyaltyPoints(address songAddress, address caller)
        internal
        view
        returns (uint16)
    {
        require(
            isOwner(songAddress, caller),
            "This is not an owner of the song."
        );
        return (songs[songAddress].owners[caller].royaltyPoints);
    }

    function checkRoyaltyPoints(address songAddress)
        external
        view
        returns (uint16)
    {
        require(
            isOwner(songAddress, msg.sender),
            "This is not an owner of the song."
        );
        return (songs[songAddress].owners[msg.sender].royaltyPoints);
    }

    function viewRoyaltyPointsOffered(address songAddress, address owner)
        public
        view
        returns (uint16)
    {
        require(
            isOwner(songAddress, owner),
            "This is not an owner of the song."
        );
        return (songs[songAddress].owners[owner].royaltyPointsOffered);
    }

    function viewRoyaltyOfferedPrice(address songAddress, address owner)
        public
        view
        returns (uint256)
    {
        require(
            isOwner(songAddress, owner),
            "This is not an owner of the song."
        );
        uint256 priceRoyalties = songs[songAddress]
            .owners[owner]
            .royaltyPointsOffered *
            songs[songAddress].owners[owner].pricePerRoyaltyPoint;
        return priceRoyalties;
    }

    function isOwner(address songAddress, address caller)
        internal
        view
        returns (bool)
    {
        require(isSongRegistered(songAddress), "The song is not registered");
        if (songs[songAddress].owners[caller].owner == caller) {
            return true;
        }
        return false;
    }

    function isCreator(address songAddress, address caller)
        internal
        view
        returns (bool)
    {
        require(isSongRegistered(songAddress), "The song is not registered");
        if (songs[songAddress].creator == caller) {
            return true;
        }
        return false;
    }

    function checkOwnership(address songAddress) external view returns (bool) {
        require(isSongRegistered(songAddress), "The song is not registered");
        if (songs[songAddress].owners[msg.sender].owner == msg.sender) {
            return true;
        }
        return false;
    }

    function isSongRegistered(address songAddress) public view returns (bool) {
        if (songs[songAddress].ownersSize > 0) {
            return true;
        } else {
            return false;
        }
    }

    function checkSongBalance(address songAddress)
        public
        view
        returns (uint256)
    {
        require(isSongRegistered(songAddress), "The song is not registered");
        require(isOwner(songAddress, msg.sender), "This is not an owner");
        return (songs[songAddress].balance);
    }

    function isListener(address songAddress) public view returns (bool) {
        if (songs[songAddress].authorizedListeners[msg.sender]) {
            return true;
        } else {
            return false;
        }
    }

    function withdraw(address songAddress) public {
        require(isSongRegistered(songAddress), "The song is not registered");
        require(
            isOwner(songAddress, msg.sender),
            "This is not an owner of the song."
        );
        uint256 songBalance = songs[songAddress].balance;
        require(songs[songAddress].balance > 0, "There is nothing to withdraw");
        require(
            songs[songAddress].balance >= MAX_ROYALTY_POINTS,
            "The current song's balance is too low to make a withdrawal"
        );

        Owner memory currentOwner = songs[songAddress].owners[msg.sender];
        uint256 amount = (songBalance / MAX_ROYALTY_POINTS) *
            currentOwner.royaltyPoints;
        amount += royaltiesPayable[msg.sender];
        msg.sender.transfer(amount);
        royaltiesPayable[msg.sender] = 0;
        songs[songAddress].balance -= amount;
    }
}
