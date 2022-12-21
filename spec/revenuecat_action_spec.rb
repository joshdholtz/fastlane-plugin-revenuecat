describe Fastlane::Actions::RevenuecatAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The revenuecat plugin is working!")

      Fastlane::Actions::RevenuecatAction.run(nil)
    end
  end
end
