var DOGIPresale = artifacts.require("DOGIPresale");

contract('DOGIPresale test', function(accounts) {
  it("ok", function() {
    return DOGIPresale.deployed().then(function(instance) {
      return instance.getRewardItem("001");
    }).then(function(item) {
      console.log(item)
      assert.equal(item.length, 7, "yes");
    })
  })
})
