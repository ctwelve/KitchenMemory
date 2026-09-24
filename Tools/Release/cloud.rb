# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module KitchenMemory
  module Release
    class Cloud
      ORIGIN = 'https://api.appstoreconnect.apple.com'

      def initialize(key_id:, issuer_id:, private_key:)
        @key_id, @issuer_id = key_id, issuer_id
        @key = OpenSSL::PKey.read(private_key)
        raise 'Expected a P-256 API key' unless @key.is_a?(OpenSSL::PKey::EC) && @key.group.curve_name == 'prime256v1'
      end

      def token
        now = Time.now.to_i
        encode = ->(value) { Base64.urlsafe_encode64(value, padding: false) }
        input = [encode.call(JSON.generate(alg: 'ES256', kid: @key_id, typ: 'JWT')),
                 encode.call(JSON.generate(iss: @issuer_id, iat: now, exp: now + 600, aud: 'appstoreconnect-v1'))].join('.')
        der = @key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(input))
        signature = OpenSSL::ASN1.decode(der).value.map { |part| part.value.to_s(2).rjust(32, "\0") }.join
        "#{input}.#{encode.call(signature)}"
      end

      def get(path)
        uri = URI.join(ORIGIN, path)
        raise 'Refusing to send API credentials outside Apple API' unless uri.scheme == 'https' && uri.host == URI(ORIGIN).host && uri.port == 443
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{token}"
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 60) { |http| http.request(request) }
        raise "Apple API returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      end

      def list(path)
        rows, included = [], []
        seen = {}
        while path
          raise 'Repeated Apple pagination URL' if seen[path]
          seen[path] = true
          page = get(path)
          rows.concat(page.fetch('data'))
          included.concat(page.fetch('included', []))
          path = page.dig('links', 'next')
        end
        [rows, included]
      end

      def self.matching_run(runs, references, tag:, sha:)
        refs = references.select { |ref| ref['type'] == 'scmGitReferences' }.to_h { |ref| [ref.fetch('id'), ref.fetch('attributes')] }
        matches = runs.select do |run|
          attrs = run.fetch('attributes')
          ref = refs[run.dig('relationships', 'sourceBranchOrTag', 'data', 'id')]
          !attrs['isPullRequestBuild'] && attrs.dig('sourceCommit', 'commitSha') == sha &&
            ref && ref['kind'] == 'TAG' && ref['canonicalName'] == "refs/tags/#{tag}" && !ref['isDeleted']
        end
        matches.max_by { |run| run.fetch('attributes').fetch('number') }
      end

      def wait_for_run(workflow:, tag:, sha:, timeout: 7200, interval: 60)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        loop do
          runs, refs = list("/v1/ciWorkflows/#{workflow}/buildRuns?include=sourceBranchOrTag&sort=-number&limit=200")
          run = self.class.matching_run(runs, refs, tag: tag, sha: sha)
          if run && run.dig('attributes', 'executionProgress') == 'COMPLETE'
            raise "Cloud build #{run['id']} finished #{run.dig('attributes', 'completionStatus')}" unless run.dig('attributes', 'completionStatus') == 'SUCCEEDED'
            return run
          end
          raise 'Timed out waiting for the tagged Cloud archive' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          puts "Waiting for Cloud archive for #{tag} at #{sha}"
          sleep interval
        end
      end

      def notarized_artifact(run_id)
        actions, = list("/v1/ciBuildRuns/#{run_id}/actions?limit=200")
        candidates = actions.flat_map do |action|
          next [] unless action.dig('attributes', 'completionStatus') == 'SUCCEEDED'
          artifacts, = list("/v1/ciBuildActions/#{action.fetch('id')}/artifacts?limit=200")
          artifacts.select { |artifact| artifact.dig('attributes', 'fileType') == 'STAPLED_NOTARIZED_ARCHIVE' }
        end
        raise "Expected one stapled notarized artifact, found #{candidates.length}" unless candidates.length == 1
        candidates.first
      end
    end
  end
end
