# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative '../Release/cloud'

class ReleaseCloudTest < Minitest::Test
  Cloud = KitchenMemory::Release::Cloud

  def run_fixture(id: 'run', number: 1, sha: 'abc', ref: 'tag', pr: false)
    {'id' => id, 'attributes' => {'number' => number, 'sourceCommit' => {'commitSha' => sha}, 'isPullRequestBuild' => pr},
     'relationships' => {'sourceBranchOrTag' => {'data' => {'id' => ref}}}}
  end

  def reference(kind: 'TAG', name: 'refs/tags/release/0.3.3', deleted: false)
    {'id' => 'tag', 'type' => 'scmGitReferences', 'attributes' => {'kind' => kind, 'canonicalName' => name, 'isDeleted' => deleted}}
  end

  def match(runs, references = [reference])
    Cloud.matching_run(runs, references, tag: 'release/0.3.3', sha: 'abc')
  end

  def test_matches_tag_and_commit_and_uses_latest_attempt
    assert_equal 'new', match([run_fixture, run_fixture(id: 'new', number: 2)])['id']
    assert_nil match([run_fixture(sha: 'other')])
    assert_nil match([run_fixture(pr: true)])
    assert_nil match([run_fixture], [reference(kind: 'BRANCH')])
    assert_nil match([run_fixture], [reference(name: 'refs/tags/release/0.3.2')])
    assert_nil match([run_fixture], [reference(deleted: true)])
    assert_nil match([run_fixture], [])
  end

  def test_jwt_signature_and_short_lifetime
    key = OpenSSL::PKey::EC.generate('prime256v1')
    client = Cloud.new(key_id: 'TEST', issuer_id: 'ISSUER', private_key: key.to_pem)
    header, payload, signature = client.token.split('.')
    claims = JSON.parse(Base64.urlsafe_decode64(payload))
    assert_equal 'ISSUER', claims['iss']
    assert_equal 600, claims['exp'] - claims['iat']
    bytes = Base64.urlsafe_decode64(signature)
    parts = [bytes[0, 32], bytes[32, 32]].map { |part| OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(part, 2)) }
    assert key.dsa_verify_asn1(OpenSSL::Digest::SHA256.digest("#{header}.#{payload}"), OpenSSL::ASN1::Sequence.new(parts).to_der)
    assert_raises(RuntimeError) { client.get('https://example.com/steal') }
  end

  def test_rejects_failed_latest_build_even_when_an_older_build_succeeded
    client = Cloud.allocate
    rows = [run_fixture, run_fixture(id: 'new', number: 2)]
    rows[0]['attributes'].merge!('executionProgress' => 'COMPLETE', 'completionStatus' => 'SUCCEEDED')
    rows[1]['attributes'].merge!('executionProgress' => 'COMPLETE', 'completionStatus' => 'FAILED')
    client.define_singleton_method(:list) { |_| [rows, [{'id' => 'tag', 'type' => 'scmGitReferences', 'attributes' => {'kind' => 'TAG', 'canonicalName' => 'refs/tags/release/0.3.3'}}]] }
    error = assert_raises(RuntimeError) { client.wait_for_run(workflow: 'workflow', tag: 'release/0.3.3', sha: 'abc') }
    assert_includes error.message, 'FAILED'
  end
  def test_completion_check_does_not_poll_an_unfinished_build
    client = Cloud.allocate
    calls = 0
    client.define_singleton_method(:list) { |_| calls += 1; [[], []] }
    client.define_singleton_method(:sleep) { |_| flunk 'Completion handoff must not poll' }
    error = assert_raises(RuntimeError) do
      client.wait_for_run(workflow: 'workflow', tag: 'release/0.3.3', sha: 'abc', timeout: 0)
    end
    assert_includes error.message, 'Timed out'
    assert_equal 1, calls
  end

  def test_selects_only_the_unique_stapled_notarized_artifact
    client = Cloud.allocate
    actions = [{'id' => 'mac', 'attributes' => {'completionStatus' => 'SUCCEEDED'}}]
    artifacts = [
      {'id' => 'store', 'attributes' => {'fileType' => 'ARCHIVE_EXPORT'}},
      {'id' => 'download', 'attributes' => {'fileType' => 'STAPLED_NOTARIZED_ARCHIVE'}}
    ]
    client.define_singleton_method(:list) { |path| [path.include?('/actions?') ? actions : artifacts, []] }
    assert_equal 'download', client.notarized_artifact('run')['id']
    artifacts << {'id' => 'duplicate', 'attributes' => {'fileType' => 'STAPLED_NOTARIZED_ARCHIVE'}}
    assert_raises(RuntimeError) { client.notarized_artifact('run') }
    artifacts.clear
    assert_raises(RuntimeError) { client.notarized_artifact('run') }
  end

end
