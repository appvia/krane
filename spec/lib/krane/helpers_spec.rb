require 'spec_helper'

describe Krane::Helpers do

  subject { Class.new { include Krane::Helpers }.new }

  describe '#name_of' do

    it 'marks a name so it can be told apart from the sentence around it' do
      expect(subject.name_of('kube-system')).to eq '`kube-system`'
    end

    it 'marks whatever it is given' do
      expect(subject.name_of(nil)).to eq '``'
    end

  end

  describe '#namespaces_of' do

    it 'names and marks a single namespace' do
      expect(subject.namespaces_of('kube-system')).to eq '`kube-system`'
    end

    it 'spells out the all-namespaces marker' do
      # A bare asterisk in the middle of a finding reads like a footnote.
      expect(subject.namespaces_of('*')).to eq '`* (All NS)`'
    end

    it 'is the same wording the tree uses' do
      expect(subject.namespaces_of('*')).to include Krane::Visualisations::TreeView::Element::ALL_NAMESPACES
    end

    it 'marks each of several namespaces separately' do
      expect(subject.namespaces_of(['kube-system', '*'])).to eq '`kube-system`, `* (All NS)`'
    end

    it 'has nothing to say about nothing' do
      expect(subject.namespaces_of(nil)).to eq ''
    end

  end

end
